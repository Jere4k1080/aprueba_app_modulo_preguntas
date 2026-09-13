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
import '../../providers/tutors_providers.dart';
import 'tutor_widgets.dart';

/// Solicitud de contacto (pantalla `tutor-contact`). Requiere plan de pago: el
/// backend responde 403 PLAN_REQUIRED al plan free.
class TutorContactScreen extends ConsumerStatefulWidget {
  const TutorContactScreen({super.key, required this.tutorId});
  final String tutorId;

  @override
  ConsumerState<TutorContactScreen> createState() => _TutorContactScreenState();
}

class _TutorContactScreenState extends ConsumerState<TutorContactScreen> {
  final _message = TextEditingController();
  bool _shareProfile = true;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.s('tut_message_required'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(tutorsRepositoryProvider).contact(
            tutorId: widget.tutorId,
            message: text,
            shareProfile: _shareProfile,
          );
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      ref.invalidate(tutorDetailProvider(widget.tutorId));
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${context.s('tut_request_sent')} ✓')));
      context.pushReplacement('/tutors/chats/${result.conversationId}');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PLAN_REQUIRED') {
        context.push('/paywall');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutor = ref.watch(tutorDetailProvider(widget.tutorId));
    final me = ref.watch(meProvider).valueOrNull;
    final analysis = ref.watch(gapAnalysisProvider);
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_contact_h'))),
      body: SafeArea(
        child: AsyncValueView<Tutor>(
          value: tutor,
          onRetry: () => ref.invalidate(tutorDetailProvider(widget.tutorId)),
          data: (data) {
            final weakAreas = analysis.valueOrNull?.subjects
                    .expand((s) => s.areasToReinforce.map((a) => a.area))
                    .take(3)
                    .toList() ??
                const <String>[];
            return Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  const Tag('⭐ Premium', variant: 'w'),
                  const SizedBox(height: 10),
                  Text(
                    '${data.name} ${context.s('tut_contact_p')}',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(context.s('tut_your_profile'),
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        InitialsAvatar(
                          initials: initialsFrom(me?.name),
                          background: '#F5B041',
                          foreground: '#1A365D',
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(me?.name ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            Text(
                              ref.watch(localPrefsProvider).gradeLabel ?? me?.gradeId ?? '',
                              style: TextStyle(fontSize: 11, color: t.muted),
                            ),
                          ]),
                        ),
                      ]),
                      if (weakAreas.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(context.s('tut_weak_areas'),
                            style: TextStyle(fontSize: 11, color: t.muted)),
                        const SizedBox(height: 5),
                        Wrap(spacing: 5, runSpacing: 5, children: [
                          for (final area in weakAreas) Tag('⚠ $area', variant: 'd'),
                        ]),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _shareProfile,
                    onChanged: (v) => setState(() => _shareProfile = v),
                    title: Text(context.s('tut_share_profile'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(context.s('tut_share_profile_p'),
                        style: TextStyle(fontSize: 11, color: t.muted)),
                  ),
                  const SizedBox(height: 8),
                  Text(context.s('tut_message'),
                      style: const TextStyle(
                          fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _message,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(hintText: context.s('tut_message_hint')),
                  ),
                  Text('💳 ${context.s('tut_payment_note')}',
                      style: TextStyle(fontSize: 11, color: t.muted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  label: context.s('tut_send_request'),
                  onPressed: _busy ? null : _send,
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
