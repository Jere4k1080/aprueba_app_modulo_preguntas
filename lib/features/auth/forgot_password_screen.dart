import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sent = false;

  Future<void> _send() async {
    await ref.read(authControllerProvider.notifier).forgot(_email.text.trim());
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s('forgot_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.s('forgot_p'), style: TextStyle(color: context.tokens.muted)),
          const SizedBox(height: 12),
          TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: context.s('email'))),
          const SizedBox(height: 12),
          if (_sent) const Tag('✓ Enlace enviado', variant: 'g'),
          const SizedBox(height: 8),
          PrimaryButton(label: context.s('send'), onPressed: _send),
          TextButton(onPressed: () => context.pop(), child: Text(context.s('cancel'))),
        ]),
      ),
    );
  }
}
