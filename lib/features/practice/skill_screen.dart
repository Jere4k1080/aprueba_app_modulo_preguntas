import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/practice_session.dart';

final skillProvider = FutureProvider.autoDispose<SkillInfo>((ref) {
  final q = ref.watch(practiceSessionProvider).question;
  return ref.watch(practiceRepositoryProvider).skill(q!.id);
});

class SkillScreen extends ConsumerWidget {
  const SkillScreen({super.key});

  IconData _resIcon(String type) => switch (type) {
        'video' => Icons.play_circle_outline,
        'pdf' => Icons.description_outlined,
        _ => Icons.track_changes,
      };

  Color _statusColor(String s) => switch (s) {
        'done' => AppColors.exito,
        'active' => AppColors.azul,
        _ => AppColors.silver,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skill = ref.watch(skillProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('exp_sk_h'))),
      body: SafeArea(
        child: AsyncValueView<SkillInfo>(
          value: skill,
          onRetry: () => ref.invalidate(skillProvider),
          data: (s) => ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name,
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  _miniTag(s.test.toUpperCase()),
                  _miniTag('Nivel ${s.level}/${s.maxLevel}'),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Text(context.s('exp_sk_status'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            const SizedBox(height: 4),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Tu dominio'),
                  const Spacer(),
                  Text('${s.masteryPercent}%',
                      style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 18, color: t.brand)),
                ]),
                const SizedBox(height: 6),
                ProgressBar(value: s.masteryPercent / 100),
                const SizedBox(height: 6),
                Text('${s.masteryCorrect} de ${s.masteryTotal} correctas', style: TextStyle(fontSize: 11, color: t.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(context.s('exp_sk_prereq'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            const SizedBox(height: 4),
            for (final p in s.prerequisites)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: _statusColor(p.status), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Tag(p.status, variant: p.status == 'done' ? 'g' : p.status == 'active' ? 'w' : 'n'),
                ]),
              ),
            const SizedBox(height: 12),
            Text(context.s('exp_sk_how'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            const SizedBox(height: 4),
            for (final r in s.resources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  onTap: r.url == null ? null : () => launchUrl(Uri.parse(r.url!), mode: LaunchMode.externalApplication),
                  child: Row(children: [
                    Icon(_resIcon(r.type), color: t.brand),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        if (r.duration != null || r.source != null)
                          Text([r.duration, r.source].where((e) => e != null).join(' · '),
                              style: TextStyle(fontSize: 11, color: t.muted)),
                      ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _miniTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}
