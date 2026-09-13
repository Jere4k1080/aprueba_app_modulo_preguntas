import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../core/storage/secure_storage.dart';
import '../local/database.dart';
import '../models/models.dart';

/// Registro, login (correo y social), verificación telefónica, refresh, logout
/// y recuperación de contraseña.
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

  Future<AuthSession> login(String email, String password) async {
    final res = await _api.post(
      Endpoints.loginEp,
      skipAuth: true,
      body: {'email': email, 'password': password},
      parse: (d) => AuthSession.fromJson((d as Map).cast<String, dynamic>()),
    );
    await _persist(res.data);
    return res.data;
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
    try {
      await _api.post(Endpoints.logout);
    } catch (_) {/* cerrar igual localmente */}
    await _storage.clear();
    await _db.wipe();
  }

  Future<bool> hasSession() async => (await _storage.refreshToken) != null;

  Future<void> _persist(AuthSession s) async {
    await _storage.saveTokens(access: s.accessToken, refresh: s.refreshToken);
    await _db.writeCache('me', s.user.toJson());
  }
}
