import 'secure_storage.dart';

/// Lee el estado de sesión antes de montar el árbol de widgets.
class SecureStorageBootstrap {
  final _storage = SecureStorage();
  Future<bool> hasSession() async => (await _storage.refreshToken) != null;
}
