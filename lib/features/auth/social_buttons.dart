import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_controller.dart';
import '../onboarding/onboarding_state.dart';

/// Botones de Google y Apple. Obtienen el idToken del SDK y llaman a /auth/social.
class SocialButtons extends ConsumerWidget {
  const SocialButtons({super.key});

  Future<void> _go(BuildContext context, WidgetRef ref, String provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final social = ref.read(socialAuthServiceProvider);
      final idToken =
          provider == 'google' ? await social.googleIdToken() : await social.appleIdToken();
      if (idToken == null) return; // cancelado / no soportado
      // Si el telefono ya se verifico en este flujo, se envia para asociarlo.
      final phoneToken = ref.read(onboardingProvider).phoneToken;
      final session = await ref.read(authControllerProvider.notifier).social(
            provider: provider,
            idToken: idToken,
            phoneToken: phoneToken.isEmpty ? null : phoneToken,
          );
      // El backend indica si falta verificar el telefono (cuenta sin numero).
      router.go(session.phoneVerificationRequired ? '/onboarding/phone' : '/home');
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$provider: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      Row(children: [
        const Expanded(child: Divider()),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(context.s('or'))),
        const Expanded(child: Divider()),
      ]),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () => _go(context, ref, 'google'),
        icon: const Icon(Icons.g_mobiledata, size: 28),
        label: Text(context.s('continue_google')),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: () => _go(context, ref, 'apple'),
        icon: const Icon(Icons.apple, size: 22),
        label: Text(context.s('continue_apple')),
      ),
    ]);
  }
}
