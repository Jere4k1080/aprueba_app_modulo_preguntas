import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';

class InviteMembersScreen extends ConsumerStatefulWidget {
  const InviteMembersScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends ConsumerState<InviteMembersScreen> {
  final _email = TextEditingController();
  final List<String> _pending = [];
  bool _busy = false;

  Future<void> _invite() async {
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    setState(() => _busy = true);
    try {
      await ref.read(groupsRepositoryProvider).invite(widget.groupId, email);
      setState(() {
        _pending.add(email);
        _email.clear();
      });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('grp_invite_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.s('grp_invite_p'), style: TextStyle(color: t.muted)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(hintText: context.s('grp_email_ph')))),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: t.brand),
              onPressed: _busy ? null : _invite,
              child: Text(context.s('grp_send')),
            ),
          ]),
          const SizedBox(height: 16),
          Text(context.s('grp_pending'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
          const SizedBox(height: 6),
          for (final e in _pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                child: Row(children: [
                  const Icon(Icons.mail_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                  const Tag('Esperando', variant: 'g'),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
