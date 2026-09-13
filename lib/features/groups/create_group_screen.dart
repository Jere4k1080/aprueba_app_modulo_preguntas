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

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  String? _subject;
  bool _busy = false;

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _subject == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).create(name: _name.text.trim(), subjectTestId: _subject!);
      ref.invalidate(groupsProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tests = ref.watch(testsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.s('grp_create'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: InputDecoration(hintText: context.s('grp_name'))),
          const SizedBox(height: 12),
          Text(context.s('grp_subject'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.tokens.muted)),
          const SizedBox(height: 6),
          AsyncValueView(
            value: tests,
            data: (list) => Wrap(children: [
              for (final t in list)
                SelectChip(
                  label: t.label,
                  selected: _subject == t.id,
                  color: AppColors.testColors[t.id],
                  onTap: () => setState(() => _subject = t.id),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: context.s('grp_create_btn'), onPressed: _busy ? null : _create),
        ]),
      ),
    );
  }
}
