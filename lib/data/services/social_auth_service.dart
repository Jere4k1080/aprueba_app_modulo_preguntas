import 'package:flutter/foundation.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../core/config/app_config.dart';

/// Obtiene el idToken de Google/Apple para enviarlo a POST /auth/social.
///
/// CONFIGURACIÓN REQUERIDA antes de usar en producción:
///  - Google: crea credenciales OAuth (Android, iOS y Web) en Google Cloud y
///    define GOOGLE_SERVER_CLIENT_ID (Web client) vía --dart-define. Añade el
///    archivo google-services.json (Android) y GoogleService-Info.plist (iOS).
///  - Apple: activa "Sign in with Apple" en el identificador de la app y en
///    Xcode (Signing & Capabilities). Solo iOS/macOS lo soportan de forma nativa.
class SocialAuthService {
  final GoogleSignIn _google = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: AppConfig.googleServerClientId,
  );

  Future<String?> googleIdToken() async {
    final account = await _google.signIn();
    if (account == null) return null; // cancelado por el usuario
    final auth = await account.authentication;
    return auth.idToken;
  }

  Future<String?> appleIdToken() async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.iOS && defaultTargetPlatform != TargetPlatform.macOS)) {
      // En Android Apple usa flujo web; configúralo si lo necesitas.
      return null;
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    return credential.identityToken;
  }

  Future<void> signOut() => _google.signOut();
}
