import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                const BrandLogo(size: 52),
                const SizedBox(height: 14),
                const Text('Aprueba',
                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(context.s('tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(.75), fontSize: 13)),
              ]),
            ),
            const Spacer(),
            ElevatedButton(
                onPressed: () => context.go('/register'), child: Text(context.s('start'))),
            const SizedBox(height: 6),
            TextButton(onPressed: () => context.go('/login'), child: Text(context.s('login'))),
          ]),
        ),
      ),
    );
  }
}
