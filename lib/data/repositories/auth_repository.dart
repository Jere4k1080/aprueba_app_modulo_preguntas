import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../local/database.dart';
import '../models/models.dart';

/// Traduce un error de Firebase Auth a ApiException con un código estable y el
/// mensaje en el idioma de la app ('es' o 'en').
ApiException authExceptionFromFirebase(FirebaseException e, String locale) {
  final (code, key) = switch (e.code) {
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' ||
    'wrong-password' ||
    'user-not-found' ||
    'missing-password' ||
    // Correo o contraseña vacíos en Android e iOS.
    'channel-error' =>
      ('AUTH_INVALID_CREDENTIALS', 'auth_err_credentials'),
    'invalid-email' => ('AUTH_INVALID_EMAIL', 'auth_err_email'),
    'user-disabled' => ('AUTH_USER_DISABLED', 'auth_err_disabled'),
    'too-many-requests' => ('AUTH_TOO_MANY_REQUESTS', 'auth_err_too_many'),
    'network-request-failed' => ('NETWORK_ERROR', 'auth_err_network'),
    _ => ('AUTH_FAILED', 'error_generic'),
  };
  return ApiException(
    code: code,
    message: S(Locale(locale)).t(key),
    details: [e.code],
  );
}

/// Login y sesión con Firebase Auth. Registro, login social, verificación
/// telefónica y recuperación de contraseña siguen contra el backend.
class AuthRepository {
  AuthRepository(this._api, this._storage, this._db);
  final ApiClient _api;
  final SecureStorage _storage;
  final AppDatabase _db;

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required bool consent,
    String locale = 'es',
    String? phoneToken,
    String? country,
    String? language,
    String? gradeId,
  }) async {
    final res = await _api.post(
      Endpoints.register,
      skipAuth: true,
      body: {
        'name': name,
        'email': email,
        'password': password,
        'consent': consent,
        'locale': locale,
        if (phoneToken != null) 'phoneToken': phoneToken,
        if (country != null) 'country': country,
        if (language != null) 'language': language,
        if (gradeId != null) 'gradeId': gradeId,
      },
      parse: (d) => AuthSession.fromJson((d as Map).cast<String, dynamic>()),
    );
    await _persist(res.data);
    return res.data;
  }

  /// Inicia sesión con correo y contraseña en Firebase Auth. Desde aquí el
  /// ApiClient envía el ID token de Firebase en cada petición.
  Future<void> login(String email, String password, {String locale = 'es'}) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseException catch (e) {
      throw authExceptionFromFirebase(e, locale);
    }
  }

  /// Social: el cliente obtiene idToken del SDK y lo envía aquí. Si el teléfono
  /// ya se verificó en este flujo, se manda el phoneToken para asociarlo.
  Future<AuthSession> social({
    required String provider,
    required String idToken,
    String? phoneToken,
  }) async {
    final res = await _api.post(
      Endpoints.social,
      skipAuth: true,
      body: {
        'provider': provider,
        'idToken': idToken,
        if (phoneToken != null) 'phoneToken': phoneToken,
      },
      parse: (d) => AuthSession.fromJson((d as Map).cast<String, dynamic>()),
    );
    await _persist(res.data);
    return res.data;
  }

  Future<void> forgotPassword(String email) =>
      _api.post(Endpoints.passwordForgot, skipAuth: true, body: {'email': email});

  // ── Verificación telefónica ────────────────────────────────────────────────
  // El SMS lo envía Firebase Auth desde el cliente (PhoneAuthService); el
  // backend valida el número, deduce país/idioma y canjea el idToken.

  Future<PhoneCodeHint> startPhoneVerification(String phone) async {
    final res = await _api.post(
      Endpoints.phoneVerificationStart,
      skipAuth: true,
      body: {'phone': phone},
      parse: (d) => PhoneCodeHint.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  /// Canjea el idToken de Firebase por el phoneToken corto del backend.
  Future<PhoneVerification> confirmPhoneVerification({
    required String firebaseIdToken,
    String? phone,
  }) async {
    final res = await _api.post(
      Endpoints.phoneVerificationConfirm,
      skipAuth: true,
      body: {
        'firebaseIdToken': firebaseIdToken,
        if (phone != null) 'phone': phone,
      },
      parse: (d) => PhoneVerification.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  /// Asocia un teléfono ya verificado a la sesión actual (flujo social).
  Future<void> attachPhone(String phoneToken) =>
      _api.patch(Endpoints.mePhone, body: {'phoneToken': phoneToken});

  Future<void> resetPassword(String token, String password) =>
      _api.post(Endpoints.passwordReset, skipAuth: true, body: {'token': token, 'password': password});

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await _storage.clear();
    await _db.wipe();
  }

  Future<bool> hasSession() async => FirebaseAuth.instance.currentUser != null;

  Future<void> _persist(AuthSession s) async {
    await _storage.saveTokens(access: s.accessToken, refresh: s.refreshToken);
    await _db.writeCache('me', s.user.toJson());
  }
}
