import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/practice_session.dart';

final explanationProvider = FutureProvider.autoDispose<Explanation>((ref) {
  final q = ref.watch(practiceSessionProvider).question;
  return ref.watch(practiceRepositoryProvider).explanation(q!.id);
});

class ExplanationScreen extends ConsumerWidget {
  const ExplanationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = ref.watch(explanationProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Explicación detallada')),
      body: SafeArea(
        child: AsyncValueView<Explanation>(
          value: exp,
          onRetry: () => ref.invalidate(explanationProvider),
          data: (e) => ListView(padding: const EdgeInsets.all(16), children: [
            Text(e.title, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
            Text(e.subject, style: TextStyle(fontSize: 12, color: t.muted)),
            const SizedBox(height: 10),
            for (final step in e.steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(step.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(step.body, style: TextStyle(fontSize: 12, color: t.muted)),
                  ]),
                ),
              ),
            if (e.verification != null)
              SoftCard(
                background: AppColors.exito.withOpacity(.08),
                borderColor: AppColors.exito,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('✅ Verificación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(e.verification!, style: TextStyle(fontSize: 12, color: t.muted)),
                ]),
              ),
            if (e.keyConcept != null) ...[
              const SizedBox(height: 10),
              SoftCard(
                background: AppColors.azul.withOpacity(.07),
                borderColor: t.brand,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 Concepto clave', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(e.keyConcept!, style: TextStyle(fontSize: 12, color: t.muted)),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: t.brand, side: BorderSide(color: t.brand)),
                onPressed: () => context.push('/practice/skill'),
                child: Text('🧠 ${context.s('exp_sk_btn')}')),
            const SizedBox(height: 6),
            OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                onPressed: () => context.push('/practice/correction'),
                child: Text('⚑ ${context.s('exp_rc_btn')}')),
          ]),
        ),
      ),
    );
  }
}
