import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Controla el idioma (es/en). El cambio actualiza toda la UI sin reiniciar.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(localPrefsProvider).locale;
    return Locale(code);
  }

  Future<void> set(String code) async {
    state = Locale(code);
    await ref.read(localPrefsProvider.notifier).setLocale(code);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
