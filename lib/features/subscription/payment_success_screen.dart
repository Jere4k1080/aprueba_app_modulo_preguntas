import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Spacer(),
            const Icon(Icons.check_circle, size: 72, color: AppColors.exito),
            const SizedBox(height: 12),
            Text(context.s('pay_ok_h'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(context.s('pay_ok_p'), textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
            const Spacer(),
            PrimaryButton(label: context.s('pay_go'), onPressed: () => context.go('/home')),
          ]),
        ),
      ),
    );
  }
}
