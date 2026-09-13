import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/database.dart';
import 'app_providers.dart';

/// Preferencias locales persistidas en Drift (tema, idioma, onboarding).
class LocalPrefsState {
  const LocalPrefsState({
    this.theme = 'system',
    this.locale = 'es',
    this.onboardingDone = false,
    this.countryCode = 'CL',
    this.gradeId,
    this.gradeLabel,
  });
  final String theme; // system | light | dark
  final String locale; // es | en
  final bool onboardingDone;
  final String countryCode;
  final String? gradeId;
  final String? gradeLabel;

  LocalPrefsState copyWith({
    String? theme,
    String? locale,
    bool? onboardingDone,
    String? countryCode,
    String? gradeId,
    String? gradeLabel,
  }) =>
      LocalPrefsState(
        theme: theme ?? this.theme,
        locale: locale ?? this.locale,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        countryCode: countryCode ?? this.countryCode,
        gradeId: gradeId ?? this.gradeId,
        gradeLabel: gradeLabel ?? this.gradeLabel,
      );
}

class LocalPrefs extends Notifier<LocalPrefsState> {
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  LocalPrefsState build() {
    _load();
    return const LocalPrefsState();
  }

  Future<void> _load() async {
    final theme = await _db.getPref('theme') ?? 'system';
    final locale = await _db.getPref('locale') ?? 'es';
    final onboarding = (await _db.getPref('onboardingDone')) == 'true';
    state = LocalPrefsState(
      theme: theme,
      locale: locale,
      onboardingDone: onboarding,
      countryCode: await _db.getPref('countryCode') ?? 'CL',
      gradeId: await _db.getPref('gradeId'),
      gradeLabel: await _db.getPref('gradeLabel'),
    );
  }

  Future<void> setTheme(String theme) async {
    state = state.copyWith(theme: theme);
    await _db.setPref('theme', theme);
  }

  Future<void> setLocale(String locale) async {
    state = state.copyWith(locale: locale);
    await _db.setPref('locale', locale);
  }

  Future<void> setOnboardingDone(bool done) async {
    state = state.copyWith(onboardingDone: done);
    await _db.setPref('onboardingDone', done.toString());
  }

  Future<void> setEducation({
    required String countryCode,
    required String gradeId,
    required String gradeLabel,
  }) async {
    state = state.copyWith(
      countryCode: countryCode,
      gradeId: gradeId,
      gradeLabel: gradeLabel,
    );
    await _db.setPref('countryCode', countryCode);
    await _db.setPref('gradeId', gradeId);
    await _db.setPref('gradeLabel', gradeLabel);
  }
}

final localPrefsProvider =
    NotifierProvider<LocalPrefs, LocalPrefsState>(LocalPrefs.new);
