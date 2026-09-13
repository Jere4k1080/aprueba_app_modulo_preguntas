import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_controller.dart';
import '../../providers/data_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.s('delete_account')),
        content: TextField(controller: controller, obscureText: true, decoration: InputDecoration(hintText: context.s('pass'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.s('cancel'))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.error), onPressed: () => Navigator.pop(context, true), child: Text(context.s('delete_account'))),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(profileRepositoryProvider).deleteAccount(controller.text);
      } catch (_) {}
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final user = ref.watch(meProvider).valueOrNull;
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.s('set_h'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          SoftCard(
            child: Row(children: [
              Expanded(child: Text(context.s('set_theme'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) => ref.read(themeControllerProvider.notifier).toggle(),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: Row(children: [
              Expanded(child: Text(context.s('set_lang'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              DropdownButton<String>(
                value: locale.languageCode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (v) => ref.read(localeControllerProvider.notifier).set(v ?? 'es'),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          SoftCard(
            onTap: () => context.push('/manage-plan'),
            child: Row(children: [
              Expanded(child: Text(context.s('set_plan'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text(user?.isPaid == true ? user!.plan.toUpperCase() : context.s('set_free'), style: TextStyle(fontSize: 12, color: t.muted)),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 8),
          SoftCard(
            child: Row(children: [
              Expanded(child: Text(context.s('set_privacy'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              const Icon(Icons.chevron_right),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(context.s('logout'))),
          const SizedBox(height: 16),
          SoftCard(
            background: AppColors.error.withOpacity(.06),
            borderColor: AppColors.error,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () => _confirmDelete(context, ref),
                child: Text(context.s('delete_account'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, color: AppColors.error)),
              ),
              const SizedBox(height: 4),
              Text(context.s('delete_account_p'), style: TextStyle(fontSize: 11, color: t.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
