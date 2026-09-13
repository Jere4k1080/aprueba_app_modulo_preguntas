import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'app_providers.dart';
import 'data_providers.dart';

/// Acciones de autenticación. Actualiza isLoggedInProvider al terminar.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required bool consent,
    String? phoneToken,
    String? country,
    String? language,
    String? gradeId,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    final locale = language ?? ref.read(localPrefsProvider).locale;
    final session = await repo.register(
      name: name,
      email: email,
      password: password,
      consent: consent,
      locale: locale,
      phoneToken: phoneToken,
      country: country,
      language: locale,
      gradeId: gradeId,
    );
    ref.read(isLoggedInProvider.notifier).state = true;
    state = const AsyncData(null);
    return session;
  }

  Future<AuthSession> login(String email, String password) async {
    state = const AsyncLoading();
    final session = await ref.read(authRepositoryProvider).login(email, password);
    ref.read(isLoggedInProvider.notifier).state = true;
    state = const AsyncData(null);
    return session;
  }

  Future<AuthSession> social({
    required String provider,
    required String idToken,
    String? phoneToken,
  }) async {
    state = const AsyncLoading();
    final session = await ref.read(authRepositoryProvider).social(
          provider: provider,
          idToken: idToken,
          phoneToken: phoneToken,
        );
    ref.read(isLoggedInProvider.notifier).state = true;
    state = const AsyncData(null);
    return session;
  }

  Future<void> forgot(String email) =>
      ref.read(authRepositoryProvider).forgotPassword(email);

  /// Valida el numero y devuelve pais/idioma detectados por el prefijo. El SMS
  /// lo envia Firebase desde el cliente (PhoneAuthService).
  Future<PhoneCodeHint> startPhoneVerification(String phone) =>
      ref.read(authRepositoryProvider).startPhoneVerification(phone);

  /// Canjea el idToken de Firebase por el phoneToken del backend.
  Future<PhoneVerification> confirmPhoneVerification({
    required String firebaseIdToken,
    String? phone,
  }) =>
      ref.read(authRepositoryProvider).confirmPhoneVerification(
            firebaseIdToken: firebaseIdToken,
            phone: phone,
          );

  /// Asocia un telefono verificado a la sesion actual (flujo social).
  Future<void> attachPhone(String phoneToken) async {
    await ref.read(authRepositoryProvider).attachPhone(phoneToken);
    ref.invalidate(meProvider);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(isLoggedInProvider.notifier).state = false;
    ref.invalidate(meProvider);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);
