import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:aprueba_app/core/network/api_client.dart';
import 'package:aprueba_app/core/network/api_exception.dart';
import 'package:aprueba_app/data/repositories/auth_repository.dart';
import 'package:aprueba_app/providers/app_providers.dart';
import 'package:aprueba_app/providers/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador HTTP falso. Decide el código de estado según la petición y guarda
/// cada petición para revisar sus cabeceras.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusFor);
  final FutureOr<int> Function(RequestOptions options) statusFor;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final status = await statusFor(options);
    final body = status == 401
        ? {
            'data': null,
            'error': {'code': 'AUTH_TOKEN_EXPIRED', 'message': 'Token vencido'},
            'meta': null,
          }
        : {'data': {'ok': true}, 'error': null, 'meta': null};
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// Imita a Firebase: forceRefresh entrega un token nuevo si hay sesión.
class _FakeTokens {
  _FakeTokens(this.current);
  String? current;
  int refreshes = 0;

  /// Si tiene valor, forceRefresh lo lanza, como Firebase sin red.
  Object? refreshError;

  Future<String?> call({bool forceRefresh = false}) async {
    if (forceRefresh) {
      refreshes++;
      // Da tiempo a que lleguen los 401 de peticiones simultáneas.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshError != null) throw refreshError!;
      if (current != null) current = 'renovado-$refreshes';
    }
    return current;
  }
}

String? _auth(RequestOptions o) => o.headers['Authorization'] as String?;

/// Cuenta las llamadas a logout sin tocar Firebase ni Drift.
class _LogoutSpy extends AuthController {
  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;
}

void main() {
  late _FakeTokens tokens;
  late int expirations;
  var language = 'es';

  ApiClient client(_FakeAdapter adapter) => ApiClient(
        idToken: tokens.call,
        language: () => language,
        dio: Dio()..httpClientAdapter = adapter,
        onSessionExpired: () => expirations++,
      );

  setUp(() {
    tokens = _FakeTokens('inicial');
    expirations = 0;
    language = 'es';
  });

  // El backend rechaza el token inicial y acepta el renovado.
  int rejectsInitial(RequestOptions o) => _auth(o) == 'Bearer inicial' ? 401 : 200;

  test('adjunta el ID token como Bearer y el idioma en Accept-Language', () async {
    final adapter = _FakeAdapter((_) => 200);
    language = 'en';
    await client(adapter).get('/me');

    expect(_auth(adapter.requests.single), 'Bearer inicial');
    expect(adapter.requests.single.headers['Accept-Language'], 'en');
  });

  test('401 y luego 200: renueva con forceRefresh y reintenta una vez', () async {
    final adapter = _FakeAdapter(rejectsInitial);
    final res = await client(adapter).get('/me');

    expect(res.data, {'ok': true});
    expect(tokens.refreshes, 1);
    expect(adapter.requests.map(_auth), ['Bearer inicial', 'Bearer renovado-1']);
    expect(expirations, 0);
  });

  test('401 dos veces: cierra la sesión una vez y no reintenta más', () async {
    final adapter = _FakeAdapter((_) => 401);
    await expectLater(
      client(adapter).get('/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(adapter.requests, hasLength(2));
    expect(tokens.refreshes, 1);
    expect(expirations, 1);
  });

  test('sin sesión no envía Authorization y un 401 cierra la sesión sin reintentar', () async {
    tokens = _FakeTokens(null);
    final adapter = _FakeAdapter((o) => _auth(o) == null ? 401 : 200);
    await expectLater(client(adapter).get('/me'), throwsA(isA<ApiException>()));

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(expirations, 1);
  });

  test('un cambio de idioma se refleja en la petición siguiente', () async {
    final adapter = _FakeAdapter((_) => 200);
    final api = client(adapter);
    await api.get('/me');
    language = 'en';
    await api.get('/me');

    expect(adapter.requests.map((o) => o.headers['Accept-Language']), ['es', 'en']);
  });

  test('401 simultáneos comparten una sola renovación', () async {
    final adapter = _FakeAdapter(rejectsInitial);
    final api = client(adapter);
    await Future.wait([api.get('/me'), api.get('/me/quota')]);

    expect(tokens.refreshes, 1);
    expect(adapter.requests.map(_auth).where((a) => a == 'Bearer inicial'), hasLength(2));
    expect(adapter.requests, hasLength(4));
    expect(expirations, 0);
  });

  test('un 401 tardío usa el token ya renovado sin forzar otra renovación', () async {
    final adapter = _FakeAdapter((o) async {
      if (o.path == '/lento' && _auth(o) == 'Bearer inicial') {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      return rejectsInitial(o);
    });
    final api = client(adapter);
    await Future.wait([api.get('/rapido'), api.get('/lento')]);

    expect(tokens.refreshes, 1);
    expect(adapter.requests.map(_auth),
        ['Bearer inicial', 'Bearer inicial', 'Bearer renovado-1', 'Bearer renovado-1']);
    expect(expirations, 0);
  });

  test('sin red y con el token vencido: sale sin Authorization y da NETWORK_ERROR', () async {
    final adapter = _FakeAdapter((o) =>
        throw DioException.connectionError(requestOptions: o, reason: 'sin red'));
    final api = ApiClient(
      idToken: ({bool forceRefresh = false}) async =>
          throw FirebaseAuthException(code: 'network-request-failed'),
      dio: Dio()..httpClientAdapter = adapter,
      onSessionExpired: () => expirations++,
    );
    await expectLater(
      api.get('/me'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR')),
    );

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(expirations, 0);
  });

  test('si Firebase no logra renovar por red, no cierra la sesión', () async {
    tokens.refreshError = FirebaseAuthException(code: 'network-request-failed');
    final adapter = _FakeAdapter((_) => 401);
    await expectLater(
      client(adapter).get('/me'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(tokens.refreshes, 1);
    expect(adapter.requests, hasLength(1));
    expect(expirations, 0);
  });

  test('el reintento conserva método, cuerpo y query', () async {
    final adapter = _FakeAdapter(rejectsInitial);
    final api = client(adapter);
    await api.post('/answers', body: {'optionId': 'b'});
    tokens.current = 'inicial';
    await api.get('/questions', query: {'page': 2});

    final retries = adapter.requests.where((o) => _auth(o) != 'Bearer inicial').toList();
    expect(retries, hasLength(2));
    expect(retries.first.method, 'POST');
    expect(retries.first.data, {'optionId': 'b'});
    expect(retries.last.method, 'GET');
    expect(retries.last.queryParameters, {'page': 2});
  });

  test('skipAuth: no envía token ni renueva ante un 401', () async {
    final adapter = _FakeAdapter((_) => 401);
    await expectLater(
      client(adapter).post('/auth/password/forgot', body: {'email': 'a@b.cl'}, skipAuth: true),
      throwsA(isA<ApiException>()),
    );

    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(tokens.refreshes, 0);
    expect(expirations, 0);
  });

  test('si Firebase invalidó la cuenta al renovar, cierra la sesión', () async {
    String? current = 'inicial';
    final adapter = _FakeAdapter((_) => 401);
    final api = ApiClient(
      idToken: ({bool forceRefresh = false}) async {
        if (!forceRefresh) return current;
        current = null; // el SDK cierra su sesión antes de lanzar
        throw FirebaseAuthException(code: 'user-disabled');
      },
      dio: Dio()..httpClientAdapter = adapter,
      onSessionExpired: () => expirations++,
    );
    await expectLater(api.get('/me'), throwsA(isA<ApiException>()));

    expect(adapter.requests, hasLength(1));
    expect(expirations, 1);
  });

  ProviderContainer sesion(_LogoutSpy spy, {required bool loggedIn}) {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(() => spy),
      isLoggedInProvider.overrideWith((ref) => loggedIn),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('la sesión vencida usa el logout explícito, que borra la caché de Drift, una sola vez', () {
    final spy = _LogoutSpy();
    final container = sesion(spy, loggedIn: true);
    final api = container.read(apiClientProvider);

    // Varios 401 simultáneos, y el /me que dispara el propio logout, llegan aquí.
    for (var i = 0; i < 3; i++) {
      api.onSessionExpired!();
    }

    expect(spy.logouts, 1);
    expect(container.read(isLoggedInProvider), isFalse);
  });

  test('sin sesión, un 401 no vuelve a hacer logout', () {
    // Sin esta guarda, logout invalida meProvider, /me responde 401 sin token y
    // vuelve a llamar a logout, en un ciclo que borra las preferencias de Drift.
    final spy = _LogoutSpy();
    sesion(spy, loggedIn: false).read(apiClientProvider).onSessionExpired!();

    expect(spy.logouts, 0);
  });

  group('errores de Firebase Auth', () {
    test('credenciales inválidas usan un código estable y el idioma de la app', () {
      final es = authExceptionFromFirebase(FirebaseAuthException(code: 'invalid-credential'), 'es');
      final en = authExceptionFromFirebase(FirebaseAuthException(code: 'wrong-password'), 'en');

      expect(es.code, 'AUTH_INVALID_CREDENTIALS');
      expect(es.message, 'Correo o contraseña incorrectos.');
      expect(en.code, 'AUTH_INVALID_CREDENTIALS');
      expect(en.message, 'Incorrect email or password.');
    });

    test('un código desconocido cae en AUTH_FAILED con el mensaje genérico', () {
      final e = authExceptionFromFirebase(FirebaseAuthException(code: 'algo-nuevo'), 'es');

      expect(e.code, 'AUTH_FAILED');
      expect(e.message, 'Algo salió mal. Intenta de nuevo.');
      expect(e.details, ['algo-nuevo']);
    });
  });
}
