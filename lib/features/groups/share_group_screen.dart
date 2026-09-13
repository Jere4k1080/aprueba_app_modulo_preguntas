import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/practice_session.dart';

class ShareGroupScreen extends ConsumerStatefulWidget {
  const ShareGroupScreen({super.key});
  @override
  ConsumerState<ShareGroupScreen> createState() => _ShareGroupScreenState();
}

class _ShareGroupScreenState extends ConsumerState<ShareGroupScreen> {
  String? _groupId;
  final _comment = TextEditingController();
  bool _busy = false;

  Future<void> _share() async {
    final q = ref.read(practiceSessionProvider).question;
    if (_groupId == null || q == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).share(_groupId!, questionId: q.id, comment: _comment.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Compartido en el grupo')));
        context.pop();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);
    final q = ref.watch(practiceSessionProvider).question;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('grp_share_to'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (q != null)
            SoftCard(
              borderColor: t.brand,
              child: Text(q.statement, style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 12),
          Text(context.s('grp_choose_group'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
          const SizedBox(height: 6),
          AsyncValueView<List<Group>>(
            value: groups,
            data: (list) => Column(children: [
              for (final g in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SoftCard(
                    borderColor: _groupId == g.id ? t.brand : null,
                    onTap: () => setState(() => _groupId = g.id),
                    child: Row(children: [
                      Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: AppColors.azul, borderRadius: BorderRadius.circular(8)), child: Text(g.name.isNotEmpty ? g.name[0] : '?', style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      if (_groupId == g.id) const Icon(Icons.check_circle, color: AppColors.exito),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          TextField(controller: _comment, maxLines: 2, decoration: InputDecoration(hintText: context.s('grp_add_comment'))),
          const SizedBox(height: 12),
          PrimaryButton(label: context.s('grp_share_btn'), onPressed: (_groupId == null || _busy) ? null : _share),
        ]),
      ),
    );
  }
}
