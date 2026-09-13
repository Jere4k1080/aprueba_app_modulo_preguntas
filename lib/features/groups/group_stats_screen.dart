import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';

class GroupStatsScreen extends ConsumerWidget {
  const GroupStatsScreen({super.key, required this.groupId});
  final String groupId;

  Widget _bar(BuildContext context, String area, int avg, {bool weak = false}) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(width: 90, child: Text(area, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(child: ProgressBar(value: avg / 100, color: weak ? AppColors.error : AppColors.exito)),
        const SizedBox(width: 8),
        Text('$avg%', style: TextStyle(fontSize: 11, color: weak ? AppColors.error : t.muted)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(groupStatsProvider(groupId));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('grp_stats_h'))),
      body: SafeArea(
        child: AsyncValueView<GroupStats>(
          value: stats,
          onRetry: () => ref.invalidate(groupStatsProvider(groupId)),
          data: (s) => ListView(padding: const EdgeInsets.all(16), children: [
            SoftCard(
              child: Column(children: [
                Text('${s.avgScore}%', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 28, color: t.brand)),
                Text('${context.s('grp_avg')} · ${s.memberCount} ${context.s('grp_members_n')}', style: TextStyle(fontSize: 11, color: t.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(context.s('grp_best'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            for (final a in s.best) _bar(context, a.area, a.avg),
            const SizedBox(height: 12),
            Text(context.s('grp_weak'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            for (final a in s.weak) _bar(context, a.area, a.avg, weak: true),
          ]),
        ),
      ),
    );
  }
}
