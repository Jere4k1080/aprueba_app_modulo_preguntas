import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/catalog_providers.dart';
import 'onboarding_state.dart';

/// Paso 5: asignaturas del grado (GET /tests?gradeId=).
class SelectTestsScreen extends ConsumerWidget {
  const SelectTestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final english = Localizations.localeOf(context).languageCode == 'en';
    final subjects = ref.watch(subjectsProvider(state.gradeId));
    final selected = state.preferences.selectedTests;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(
          title: Text(english ? 'Choose your subjects or tests' : 'Elige tus asignaturas o pruebas')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: AsyncValueView<List<TestInfo>>(
              value: subjects,
              onRetry: () => ref.invalidate(subjectsProvider(state.gradeId)),
              data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
                Text('5 / 6',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: t.muted)),
                const SizedBox(height: 8),
                Text(
                  english
                      ? 'For ${state.gradeLabel ?? 'your stage'}, choose what you want to practise.'
                      : 'Para ${state.gradeLabel ?? 'tu grado'}, selecciona lo que quieres practicar.',
                  style: TextStyle(color: t.muted),
                ),
                const SizedBox(height: 14),
                Wrap(children: [
                  for (final subject in list)
                    SelectChip(
                      label: subject.label,
                      selected: selected.contains(subject.id),
                      color: colorFromHex(subject.color),
                      onTap: () => ref.read(onboardingProvider.notifier).toggleTest(subject.id),
                    ),
                ]),
                const SizedBox(height: 10),
                if (list.any((s) => !s.hasQuestions))
                  Text(
                    english
                        ? 'Some subjects are still building their question bank; you will get content as it lands.'
                        : 'Algunas asignaturas aun estan cargando preguntas; recibiras contenido en cuanto este listo.',
                    style: TextStyle(fontSize: 12, color: t.muted),
                  ),
                const SizedBox(height: 6),
                Text(
                  english
                      ? 'You can change these subjects later in Settings.'
                      : 'Podras cambiar estas asignaturas desde Ajustes.',
                  style: TextStyle(fontSize: 12, color: t.muted),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: english ? 'Continue' : 'Continuar',
              onPressed: selected.isEmpty ? null : () => context.push('/onboarding/account'),
            ),
          ),
        ]),
      ),
    );
  }
}
