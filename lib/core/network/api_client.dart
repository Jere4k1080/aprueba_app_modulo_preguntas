import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// Entrega el ID token de Firebase del usuario actual, o null sin sesión.
typedef IdTokenSource = Future<String?> Function({bool forceRefresh});

/// Cliente HTTP central. Adjunta el ID token de Firebase y el idioma de la app,
/// renueva el token una vez ante un 401 y desempaqueta el envelope
/// { data, error, meta }.
class ApiClient {
  ApiClient({
    required IdTokenSource idToken,
    String Function()? language,
    Dio? dio,
    this.onSessionExpired,
  })  : _idToken = idToken,
        _language = language ?? (() => 'es'),
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Accept'] = 'application/json';
    _dio.interceptors.add(_authInterceptor());
  }

  final Dio _dio;
  final IdTokenSource _idToken;
  final String Function() _language;

  /// Se llama cuando el token renovado tampoco sirve o ya no hay sesión.
  final void Function()? onSessionExpired;

  /// Renovación en curso. Los 401 simultáneos esperan la misma.
  Future<String?>? _renewing;

  static const _retried = 'authRetried';

  Dio get raw => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Se lee en cada petición para que un cambio de idioma aplique de inmediato.
        options.headers['Accept-Language'] = _language();
        // El reintento ya lleva el token renovado.
        if (options.extra['skipAuth'] != true && options.extra[_retried] != true) {
          String? token;
          try {
            token = await _idToken(forceRefresh: false);
          } catch (_) {
            // Sin red y con el token vencido, Firebase no logra renovarlo. La
            // petición sale sin token y termina en NETWORK_ERROR, y el
            // repositorio sirve la caché. Con red, el 401 activa la renovación.
          }
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final ro = e.requestOptions;
        if (e.response?.statusCode != 401 || ro.extra['skipAuth'] == true) {
          return handler.next(e);
        }
        if (ro.extra[_retried] == true) {
          onSessionExpired?.call();
          return handler.next(e);
        }
        String? token;
        try {
          token = await _idToken(forceRefresh: false);
          // Si otra petición ya renovó después de que esta saliera, basta con
          // el token actual. Si no, se fuerza la renovación.
          if (token != null && 'Bearer $token' == ro.headers['Authorization']) {
            token = await (_renewing ??= _idToken(forceRefresh: true)
                .whenComplete(() => _renewing = null));
          }
        } catch (_) {
          // Firebase no pudo renovar. Sin red o con demasiadas solicitudes la
          // sesión sigue abierta. Si invalidó la cuenta, su SDK ya cerró la
          // sesión y no queda usuario: se cierra también aquí.
          final current = await _idToken(forceRefresh: false).catchError((_) => '');
          if (current == null) onSessionExpired?.call();
          return handler.next(e);
        }
        if (token == null) {
          onSessionExpired?.call();
          return handler.next(e);
        }
        final retry = ro.copyWith(
          headers: {...ro.headers, 'Authorization': 'Bearer $token'},
          extra: {...ro.extra, _retried: true},
        );
        try {
          handler.resolve(await _dio.fetch(retry));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    );
  }

  // ---- Métodos genéricos ----

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parse,
    bool skipAuth = false,
  }) =>
      _send<T>(() => _dio.get(path,
          queryParameters: query, options: Options(extra: {'skipAuth': skipAuth})),
          parse);

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(dynamic data)? parse,
    bool skipAuth = false,
  }) =>
      _send<T>(
          () => _dio.post(path,
              data: body,
              options: Options(headers: headers, extra: {'skipAuth': skipAuth})),
          parse);

  Future<ApiResponse<T>> put<T>(String path,
          {Object? body, T Function(dynamic data)? parse}) =>
      _send<T>(() => _dio.put(path, data: body), parse);

  Future<ApiResponse<T>> patch<T>(String path,
          {Object? body, T Function(dynamic data)? parse}) =>
      _send<T>(() => _dio.patch(path, data: body), parse);

  Future<ApiResponse<T>> delete<T>(String path,
          {Object? body, T Function(dynamic data)? parse}) =>
      _send<T>(() => _dio.delete(path, data: body), parse);

  Future<ApiResponse<T>> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(dynamic data)? parse,
  ) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is Map<String, dynamic>) {
          throw ApiException.fromMap(error, statusCode: res.statusCode);
        }
        final data = body['data'];
        final meta = body['meta'] as Map<String, dynamic>?;
        return ApiResponse<T>(
          data: parse != null ? parse(data) : data as T,
          meta: meta,
        );
      }
      return ApiResponse<T>(data: parse != null ? parse(body) : body as T);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['error'] is Map) {
        throw ApiException.fromMap(
          data['error'] as Map<String, dynamic>,
          statusCode: e.response?.statusCode,
        );
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException.network();
      }
      throw ApiException(
        code: 'HTTP_${e.response?.statusCode ?? 'ERR'}',
        message: e.message ?? 'Error de red',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
