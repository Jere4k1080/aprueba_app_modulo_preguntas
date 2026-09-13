import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_controller.dart';
import '../onboarding/onboarding_state.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _consent = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(isLoggedInProvider)) {
      context.go('/onboarding/format');
      return;
    }
    final email = _email.text.trim();
    if (!email.contains('@') || _pass.text.length < 6 || _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisa nombre, correo y contraseña (mín. 6).')));
      return;
    }
    if (!_consent) return;
    final onboarding = ref.read(onboardingProvider);
    if (!onboarding.isPhoneVerified || onboarding.gradeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Completa la verificacion telefonica y la seleccion de grado.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
        name: _name.text.trim(),
        email: email,
        password: _pass.text,
        consent: _consent,
        phoneToken: onboarding.phoneToken,
        country: onboarding.countryCode,
        language: onboarding.locale,
        gradeId: onboarding.gradeId,
      );
      if (mounted) context.go('/onboarding/format');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s('reg_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'Your phone has been verified. Complete your details to save your progress.'
                : 'Tu telefono ya fue verificado. Completa tus datos para guardar tu progreso.',
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: InputDecoration(hintText: context.s('name'))),
          const SizedBox(height: 10),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: context.s('email'))),
          const SizedBox(height: 10),
          TextField(controller: _pass, obscureText: true, decoration: InputDecoration(hintText: context.s('pass'))),
          const SizedBox(height: 10),
          SoftCard(
            child: Row(children: [
              Switch(value: _consent, onChanged: (v) => setState(() => _consent = v)),
              Expanded(child: Text(context.s('consent'), style: const TextStyle(fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 8),
          const Tag('+10 preguntas/día', variant: 'g'),
          const SizedBox(height: 12),
          PrimaryButton(label: context.s('create'), onPressed: _busy ? null : _submit),
        ]),
      ),
    );
  }
}
