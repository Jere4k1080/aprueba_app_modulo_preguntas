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
import '../../providers/tutors_providers.dart';
import 'tutor_widgets.dart';

/// Bandeja de conversaciones con tutores.
class TutorChatsScreen extends ConsumerWidget {
  const TutorChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final t = context.tokens;
    final localeCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('tut_chats'))),
      body: SafeArea(
        child: AsyncValueView<List<Conversation>>(
          value: conversations,
          onRetry: () => ref.invalidate(conversationsProvider),
          data: (list) => list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text(context.s('tut_chats_empty'),
                        textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(conversationsProvider);
                    await ref.read(conversationsProvider.future);
                  },
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    for (final c in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SoftCard(
                          onTap: () => context.push('/tutors/chats/${c.id}'),
                          child: Row(children: [
                            InitialsAvatar(
                                initials: c.tutorInitials, background: c.tutorColor, size: 40),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(c.tutorName,
                                        style: const TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                  ),
                                  Text(relativeDate(c.lastMessageAt, localeCode),
                                      style: TextStyle(fontSize: 10, color: t.muted)),
                                ]),
                                const SizedBox(height: 2),
                                Text(c.lastMessagePreview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: t.muted)),
                              ]),
                            ),
                            if (c.unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Badge(label: Text('${c.unreadCount}')),
                            ],
                          ]),
                        ),
                      ),
                  ]),
                ),
        ),
      ),
    );
  }
}

/// Chat con un tutor (pantalla `tutor-chat`). Polling REST: los mensajes se
/// refrescan cada AppConfig.chatPollInterval mientras la pantalla está abierta.
class TutorChatScreen extends ConsumerStatefulWidget {
  const TutorChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends ConsumerState<TutorChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Al abrir el chat se consumen los no leidos: hay que refrescar el badge.
    final repo = ref.read(chatRepositoryProvider);
    Future.microtask(() async {
      try {
        await repo.markRead(widget.conversationId);
      } catch (_) {/* el polling lo reintenta */}
      if (mounted) ref.invalidate(conversationsProvider);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(widget.conversationId, text);
      if (!mounted) return;
      _input.clear();
      ref.invalidate(conversationMessagesProvider(widget.conversationId));
      ref.invalidate(conversationsProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PLAN_REQUIRED') {
        context.push('/paywall');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleSharing(bool value) async {
    try {
      await ref.read(chatRepositoryProvider).setContactSharing(widget.conversationId, value);
      if (!mounted) return;
      ref.invalidate(conversationDetailProvider(widget.conversationId));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'PLAN_REQUIRED') {
        context.push('/paywall');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(conversationDetailProvider(widget.conversationId));
    final messages = ref.watch(conversationMessagesProvider(widget.conversationId));
    final t = context.tokens;

    return Scaffold(
      appBar: AppBar(
        title: detail.maybeWhen(
          data: (d) => Row(children: [
            InitialsAvatar(initials: d.tutorInitials, background: d.tutorColor, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.tutorName,
                    style: const TextStyle(
                        fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 14)),
                if (d.tutorOnline)
                  Text('● ${context.s('tut_online_now')}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.exito, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          orElse: () => Text(context.s('tut_chats')),
        ),
        actions: [
          detail.maybeWhen(
            data: (d) => IconButton(
              tooltip: context.s('tut_rate'),
              onPressed: () => context.push('/tutors/${d.tutorId}/review'),
              icon: const Icon(Icons.star_rounded, color: AppColors.oro),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          detail.maybeWhen(
            data: (d) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _ContactSharingCard(
                sharing: d.contactSharing,
                onChanged: _toggleSharing,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: AsyncValueView<List<ChatMessage>>(
              value: messages,
              onRetry: () => ref.invalidate(conversationMessagesProvider(widget.conversationId)),
              data: (list) => ListView.builder(
                reverse: true, // la API devuelve del más reciente al más antiguo
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final m = list[i];
                  return Align(
                    alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * .78),
                      decoration: BoxDecoration(
                        color: m.mine ? t.brand : t.soft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: m.mine ? t.brand : t.line, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            m.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(m.text,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: m.mine ? Colors.white : t.ink)),
                          if (m.createdAt != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              relativeDate(m.createdAt,
                                  Localizations.localeOf(context).languageCode),
                              style: TextStyle(
                                  fontSize: 9,
                                  color: m.mine ? Colors.white70 : t.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sending ? null : _send(),
                  decoration: InputDecoration(hintText: context.s('tut_type_message')),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: t.brand, padding: const EdgeInsets.all(14)),
                onPressed: _sending ? null : _send,
                child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ContactSharingCard extends StatelessWidget {
  const _ContactSharingCard({required this.sharing, required this.onChanged});
  final ContactSharing sharing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SoftCard(
      borderColor: AppColors.oro,
      background: AppColors.oro.withOpacity(.09),
      padding: const EdgeInsets.all(11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('🔒 ${context.s('tut_share_whatsapp')}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Switch.adaptive(value: sharing.myConsent, onChanged: onChanged),
        ]),
        Text(context.s('tut_share_whatsapp_p'), style: TextStyle(fontSize: 11, color: t.muted)),
        if (sharing.mutual && sharing.tutorWhatsapp != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.phone_rounded, size: 16, color: AppColors.exito),
            const SizedBox(width: 6),
            Text(sharing.tutorWhatsapp!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ] else if (sharing.myConsent && !sharing.tutorConsent)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(context.s('tut_waiting_tutor'),
                style: TextStyle(fontSize: 11, color: t.muted)),
          ),
      ]),
    );
  }
}
