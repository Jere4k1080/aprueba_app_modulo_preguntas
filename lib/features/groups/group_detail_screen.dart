import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(group.valueOrNull?.name ?? context.s('grp_tab'))),
      body: SafeArea(
        child: AsyncValueView<Group>(
          value: group,
          onRetry: () => ref.invalidate(groupDetailProvider(groupId)),
          data: (g) => ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
                Text('${g.subject} · ${g.memberCount} ${context.s('grp_members_n')}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.75))),
              ]),
            ),
            const SizedBox(height: 12),
            Text(context.s('grp_detail_members'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
            for (final m in g.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(backgroundColor: AppColors.azul, child: Text(m.name.isNotEmpty ? m.name[0] : '?', style: const TextStyle(color: Colors.white))),
                title: Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(m.activeToday ? 'Activo hoy' : '—', style: TextStyle(fontSize: 11, color: t.muted)),
                trailing: m.score != null ? Tag('${m.score}%', variant: 'g') : null,
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => context.push('/groups/$groupId/invite'), child: Text('+ ${context.s('grp_invite_h')}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => context.push('/groups/$groupId/stats'), child: const Text('📊 Stats'))),
            ]),
          ]),
        ),
      ),
    );
  }
}
