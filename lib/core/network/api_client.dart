import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'endpoints.dart';

/// Cliente HTTP central. Adjunta el access token, renueva con el refresh token
/// de forma transparente (rotación) y desempaqueta el envelope { data, error, meta }.
class ApiClient {
  ApiClient(this._storage, {Dio? dio, this.onSessionExpired})
      : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = AppConfig.apiBaseUrl
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Accept'] = 'application/json'
      ..headers['Accept-Language'] = 'es';
    _dio.interceptors.add(_authInterceptor());
  }

  final Dio _dio;
  final SecureStorage _storage;
  final void Function()? onSessionExpired;
  bool _refreshing = false;

  Dio get raw => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;
        if (!skipAuth) {
          final token = await _storage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final is401 = e.response?.statusCode == 401;
        final isRefreshCall = e.requestOptions.path == Endpoints.refresh;
        if (is401 && !isRefreshCall && !_refreshing) {
          try {
            final ok = await _tryRefresh();
            if (ok) {
              final clone = await _retry(e.requestOptions);
              return handler.resolve(clone);
            }
          } catch (_) {/* cae al manejo normal */}
          onSessionExpired?.call();
        }
        handler.next(e);
      },
    );
  }

  Future<bool> _tryRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return false;
    _refreshing = true;
    try {
      final res = await _dio.post(
        Endpoints.refresh,
        data: {'refreshToken': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = (res.data['data'] ?? {}) as Map<String, dynamic>;
      await _storage.saveTokens(
        access: data['accessToken'] as String,
        refresh: (data['refreshToken'] ?? refresh) as String,
      );
      return true;
    } finally {
      _refreshing = false;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions ro) {
    return _dio.request(
      ro.path,
      data: ro.data,
      queryParameters: ro.queryParameters,
      options: Options(method: ro.method, headers: ro.headers, extra: ro.extra),
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
