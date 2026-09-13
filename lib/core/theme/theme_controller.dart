import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

/// Controla el modo claro/oscuro. Persiste en la tabla local de preferencias.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(localPrefsProvider);
    final stored = prefs.theme;
    return stored == 'dark'
        ? ThemeMode.dark
        : stored == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await ref
        .read(localPrefsProvider.notifier)
        .setTheme(next == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(localPrefsProvider.notifier).setTheme(
        mode == ThemeMode.dark ? 'dark' : mode == ThemeMode.light ? 'light' : 'system');
  }
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeMode>(ThemeController.new);
