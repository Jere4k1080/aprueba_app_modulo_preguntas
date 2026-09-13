import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import 'education_catalog.dart';

/// Datos temporales del alta. Las preferencias de practica se guardan aparte
/// porque son el contrato existente de /me/preferences.
class OnboardingState {
  const OnboardingState({
    this.phone = '',
    this.phoneToken = '',
    this.verificationId = '',
    this.resendToken,
    this.countryCode = 'CL',
    this.locale = 'es',
    this.gradeId,
    this.gradeLabel,
    this.preferences = const Preferences(selectedTests: []),
  });

  final String phone;

  /// Token corto que emite el backend tras validar el idToken de Firebase.
  final String phoneToken;

  /// Id de verificación de Firebase (para canjear el código SMS).
  final String verificationId;
  final int? resendToken;

  final String countryCode; // CL | UK
  final String locale; // es | en
  final String? gradeId;
  final String? gradeLabel;
  final Preferences preferences;

  bool get isPhoneVerified => phoneToken.isNotEmpty;
  bool get codeRequested => verificationId.isNotEmpty;

  OnboardingState copyWith({
    String? phone,
    String? phoneToken,
    String? verificationId,
    int? resendToken,
    String? countryCode,
    String? locale,
    String? gradeId,
    String? gradeLabel,
    Preferences? preferences,
    bool clearGrade = false,
  }) =>
      OnboardingState(
        phone: phone ?? this.phone,
        phoneToken: phoneToken ?? this.phoneToken,
        verificationId: verificationId ?? this.verificationId,
        resendToken: resendToken ?? this.resendToken,
        countryCode: countryCode ?? this.countryCode,
        locale: locale ?? this.locale,
        gradeId: clearGrade ? null : gradeId ?? this.gradeId,
        gradeLabel: clearGrade ? null : gradeLabel ?? this.gradeLabel,
        preferences: preferences ?? this.preferences,
      );
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void setPhone(String phone) => state = state.copyWith(phone: phone);

  /// Guarda el id de verificación devuelto por Firebase al pedir el SMS.
  /// Un id vacío (auto-verificación de Android) no debe sobrescribir el válido.
  void codeSent({required String verificationId, int? resendToken}) => state = state.copyWith(
        verificationId: verificationId.isEmpty ? state.verificationId : verificationId,
        resendToken: resendToken,
      );

  void verifyPhone(String phoneToken) => state = state.copyWith(phoneToken: phoneToken);

  /// País e idioma detectados por el backend a partir del prefijo telefónico.
  void applyDetectedLocale({String? country, String? language}) {
    final code = EducationCatalog.normalizeCountry(country ?? state.countryCode);
    state = state.copyWith(
      countryCode: code,
      locale: language ?? EducationCatalog.languageFor(code),
    );
  }

  /// Cambiar de país invalida el grado y las asignaturas elegidas.
  void setCountry(String countryCode) {
    final code = EducationCatalog.normalizeCountry(countryCode);
    state = state.copyWith(
      countryCode: code,
      locale: EducationCatalog.languageFor(code),
      clearGrade: true,
      preferences: const Preferences(selectedTests: []),
    );
  }

  void setLocale(String locale) => state = state.copyWith(locale: locale);

  void setGrade({required String id, required String label}) => state = state.copyWith(
        gradeId: id,
        gradeLabel: label,
        preferences: state.preferences.copyWith(selectedTests: const []),
      );

  void toggleTest(String id) {
    final list = [...state.preferences.selectedTests];
    list.contains(id) ? list.remove(id) : list.add(id);
    state = state.copyWith(preferences: state.preferences.copyWith(selectedTests: list));
  }

  void setFormat(String format) =>
      state = state.copyWith(preferences: state.preferences.copyWith(format: format));

  void setDifficulty(String difficulty) =>
      state = state.copyWith(preferences: state.preferences.copyWith(difficulty: difficulty));

  /// Preferencias listas para PUT /me/preferences (incluye país, idioma y grado).
  Preferences preferencesPayload() => state.preferences.copyWith(
        country: state.countryCode,
        language: state.locale,
        gradeId: state.gradeId,
      );
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
