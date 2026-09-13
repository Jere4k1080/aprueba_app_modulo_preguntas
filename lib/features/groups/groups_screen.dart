import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Text(context.s('grp_my'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
              const Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.brand),
                onPressed: () => context.push('/groups/create'),
                child: Text('＋ ${context.s('grp_create')}'),
              ),
            ]),
          ),
          Expanded(
            child: AsyncValueView<List<Group>>(
              value: groups,
              onRetry: () => ref.invalidate(groupsProvider),
              data: (list) => list.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(context.s('grp_empty'), textAlign: TextAlign.center, style: TextStyle(color: t.muted))))
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(groupsProvider),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        for (final g in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: () => context.push('/groups/${g.id}'),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Container(
                                    width: 40, height: 40, alignment: Alignment.center,
                                    decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(12)),
                                    child: Text(g.name.isNotEmpty ? g.name[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(g.name, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
                                      Text('${g.subject} · ${g.memberCount} ${context.s('grp_members_n')}', style: TextStyle(fontSize: 11, color: t.muted)),
                                    ]),
                                  ),
                                ]),
                                if (g.avgScore != null) ...[
                                  const SizedBox(height: 10),
                                  ProgressBar(value: g.avgScore! / 100),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Text('${context.s('grp_avg')}: ${g.avgScore}%', style: TextStyle(fontSize: 11, color: t.muted)),
                                    const Spacer(),
                                    if (g.yourScore != null) Text('${context.s('grp_your')}: ${g.yourScore}%', style: TextStyle(fontSize: 11, color: t.muted)),
                                  ]),
                                ],
                              ]),
                            ),
                          ),
                      ]),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}
