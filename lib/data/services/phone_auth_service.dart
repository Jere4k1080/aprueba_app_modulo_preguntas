import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/config/app_config.dart';
import '../../firebase_options.dart';

/// Resultado de pedir el SMS. `autoIdToken` viene con valor cuando Android
/// resolvió la verificación solo (auto-retrieval) y ya no hace falta el código.
class PhoneCodeRequest {
  const PhoneCodeRequest({required this.verificationId, this.autoIdToken, this.resendToken});
  final String verificationId;
  final String? autoIdToken;
  final int? resendToken;

  bool get autoVerified => autoIdToken != null;
}

class PhoneAuthException implements Exception {
  PhoneAuthException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => 'PhoneAuthException($code): $message';
}

/// Verificación telefónica con Firebase Auth phone sign-in.
///
/// Flujo real: `sendCode` dispara el SMS, `confirmCode` canjea el código por un
/// idToken de Firebase que el backend valida en POST /auth/phone/verify-code.
///
/// Modo desarrollo (AppConfig.usePhoneDevToken): no se contacta a Firebase y se
/// devuelve el token `dev:<telefono>` que acepta el backend con
/// PHONE_AUTH_ALLOW_DEV_TOKEN=true. Permite recorrer el onboarding completo sin
/// tener configurado el proveedor de teléfono.
class PhoneAuthService {
  PhoneAuthService({FirebaseAuth? auth}) : _auth = auth;
  final FirebaseAuth? _auth;

  static const _devVerificationId = 'dev-verification';

  bool get isDevMode => AppConfig.usePhoneDevToken;

  /// main() inicializa Firebase con DefaultFirebaseOptions y aquí se reutiliza
  /// esa app. Si el servicio corre sin pasar por main(), se inicializa con las
  /// mismas opciones.
  Future<FirebaseAuth> _firebase() async {
    if (_auth != null) return _auth;
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } on FirebaseException catch (e) {
        throw PhoneAuthException(
          e.message ?? 'Firebase no esta configurado en esta app',
          code: e.code,
        );
      } catch (e) {
        // UnsupportedError en plataformas sin DefaultFirebaseOptions,
        // MissingPluginException si falta el plugin nativo.
        throw PhoneAuthException('Firebase no esta configurado: $e');
      }
    }
    return FirebaseAuth.instance;
  }

  Future<PhoneCodeRequest> sendCode(String phone, {int? resendToken}) async {
    if (isDevMode) {
      return const PhoneCodeRequest(verificationId: _devVerificationId);
    }
    final auth = await _firebase();
    final completer = Completer<PhoneCodeRequest>();
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          if (completer.isCompleted) return;
          try {
            final idToken = await _signIn(auth, credential);
            completer.complete(PhoneCodeRequest(
              verificationId: credential.verificationId ?? '',
              autoIdToken: idToken,
            ));
          } catch (e) {
            completer.completeError(PhoneAuthException('$e'));
          }
        },
        verificationFailed: (e) {
          if (completer.isCompleted) return;
          completer.completeError(PhoneAuthException(
            e.message ?? 'No se pudo enviar el SMS',
            code: e.code,
          ));
        },
        codeSent: (verificationId, token) {
          if (completer.isCompleted) return;
          completer.complete(PhoneCodeRequest(verificationId: verificationId, resendToken: token));
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (completer.isCompleted) return;
          completer.complete(PhoneCodeRequest(verificationId: verificationId));
        },
      );
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthException(e.message ?? 'No se pudo enviar el SMS', code: e.code);
    }
    // iOS no dispara codeAutoRetrievalTimeout: sin este timeout el future podria
    // no completarse nunca y la pantalla quedaria bloqueada.
    return completer.future.timeout(
      const Duration(seconds: 75),
      onTimeout: () => throw PhoneAuthException('El envio del SMS tardo demasiado'),
    );
  }

  /// Devuelve el idToken de Firebase (o el token de desarrollo) para el backend.
  Future<String> confirmCode({
    required String verificationId,
    required String code,
    required String phone,
  }) async {
    if (isDevMode) return 'dev:${phone.replaceAll(RegExp(r'[\s()-]'), '')}';
    try {
      final auth = await _firebase();
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      return await _signIn(auth, credential);
    } on FirebaseAuthException catch (e) {
      throw PhoneAuthException(e.message ?? 'Codigo invalido', code: e.code);
    }
  }

  Future<String> _signIn(FirebaseAuth auth, PhoneAuthCredential credential) async {
    final result = await auth.signInWithCredential(credential);
    String? token;
    try {
      token = await result.user?.getIdToken();
    } finally {
      // La sesión de Firebase es la sesión de la app. La de teléfono solo prueba
      // el número y se cierra aquí; el ID token sigue sirviendo una hora para
      // canjearlo en el backend.
      await auth.signOut();
    }
    if (token == null || token.isEmpty) {
      throw PhoneAuthException('Firebase no devolvio un idToken');
    }
    return token;
  }

  /// Cierra la sesión de Firebase. _signIn ya cierra la de teléfono y esta
  /// llamada de VerifyPhoneScreen queda como respaldo.
  Future<void> signOut() async {
    if (isDevMode) return;
    try {
      final auth = await _firebase();
      await auth.signOut();
    } catch (_) {/* no bloquea el onboarding */}
  }
}
