import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el refresh token en el llavero seguro del dispositivo
/// (Keychain en iOS, Keystore en Android), tal como pide la spec.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _kRefresh = 'aprueba_refresh_token';
  static const _kAccess = 'aprueba_access_token';
  static const _kDeviceId = 'aprueba_device_id';

  Future<void> saveTokens(
      {required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveAccessToken(String access) =>
      _storage.write(key: _kAccess, value: access);

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);

  Future<String?> deviceId() async {
    var id = await _storage.read(key: _kDeviceId);
    if (id == null) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _kDeviceId, value: id);
    }
    return id;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
