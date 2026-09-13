import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/auth_controller.dart';
import 'social_buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text.trim(), _pass.text);
      if (mounted) context.go('/home');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s('login_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: context.s('email'))),
          const SizedBox(height: 10),
          TextField(controller: _pass, obscureText: true, decoration: InputDecoration(hintText: context.s('pass'))),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.push('/forgot'), child: Text(context.s('forgot'))),
          ),
          PrimaryButton(label: context.s('login_h'), onPressed: _busy ? null : _submit),
          const SizedBox(height: 16),
          const SocialButtons(),
        ]),
      ),
    );
  }
}
