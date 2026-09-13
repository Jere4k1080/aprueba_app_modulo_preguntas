import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/tutors_providers.dart';

/// Análisis de falencias (pantalla `tutor-analysis`, premium).
class GapAnalysisScreen extends ConsumerWidget {
  const GapAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(gapAnalysisProvider);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_gap_h'))),
      body: SafeArea(
        child: analysis.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            // El plan free recibe 403 PLAN_REQUIRED: se ofrece el paywall.
            if (e is ApiException && e.code == 'PLAN_REQUIRED') {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🎯', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  Text(context.s('tut_gap_h'),
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(context.s('tut_premium_analysis'),
                      textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
                  const SizedBox(height: 18),
                  PrimaryButton(
                    label: context.s('up_cta'),
                    onPressed: () => context.push('/paywall'),
                  ),
                ]),
              );
            }
            final message = e is ApiException ? e.message : context.s('error_generic');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 40),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(gapAnalysisProvider),
                    child: Text(context.s('retry')),
                  ),
                ]),
              ),
            );
          },
          data: (data) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(gapAnalysisProvider);
              await ref.read(gapAnalysisProvider.future);
            },
            child: ListView(padding: const EdgeInsets.all(16), children: [
              const Tag('⭐ Premium', variant: 'w'),
              const SizedBox(height: 10),
              SoftCard(
                borderColor: t.brand,
                background: t.brand.withOpacity(.05),
                child: Row(children: [
                  const Text('📊', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.s('tut_gap_diagnosis'),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                        '${context.s('tut_gap_based_on')} ${data.basedOnExercises} ${context.s('tut_gap_exercises')}',
                        style: TextStyle(fontSize: 11, color: t.muted),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Text(context.s('tut_gap_sorted'), style: TextStyle(fontSize: 12, color: t.muted)),
              const SizedBox(height: 10),
              if (data.subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(context.s('tut_gap_empty'),
                      textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
                ),
              for (final subject in data.subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubjectCard(subject: subject),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.subject});
  final GapSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final variant = switch (subject.status) {
      'critical' => 'd',
      'warning' => 'w',
      _ => 'g',
    };
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(subject.label,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Tag('${subject.mastery}% ${context.s('tut_mastery')}', variant: variant),
        ]),
        const SizedBox(height: 8),
        ProgressBar(value: subject.mastery / 100, color: colorFromHex(subject.color), height: 7),
        const SizedBox(height: 8),
        if (!subject.hasData)
          Text(context.s('tut_gap_no_data'), style: TextStyle(fontSize: 11, color: t.muted))
        else ...[
          Text(context.s('tut_areas_reinforce'), style: TextStyle(fontSize: 11, color: t.muted)),
          const SizedBox(height: 5),
          Wrap(spacing: 5, runSpacing: 5, children: [
            for (final area in subject.areasToReinforce) Tag('⚠ ${area.area}', variant: 'd'),
          ]),
        ],
        if (subject.recommendedTutorCount > 0) ...[
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              // Filtra el marketplace por la asignatura débil y vuelve a la lista.
              ref.read(tutorFiltersProvider.notifier).setSubject(subject.testId);
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/tutors');
              }
            },
            child: Text(
                '${context.s('tut_see')} ${subject.recommendedTutorCount} ${context.s('tut_recommended')} →'),
          ),
        ],
      ]),
    );
  }
}
