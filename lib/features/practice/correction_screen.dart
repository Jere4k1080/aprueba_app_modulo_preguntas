import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/medal_coin.dart';
import '../../providers/app_providers.dart';
import '../../providers/practice_session.dart';

class CorrectionScreen extends ConsumerStatefulWidget {
  const CorrectionScreen({super.key});
  @override
  ConsumerState<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends ConsumerState<CorrectionScreen> {
  final _reasons = ['exp_rc_r1', 'exp_rc_r2', 'exp_rc_r3', 'exp_rc_r4', 'exp_rc_r5'];
  final _codes = ['wrong_answer', 'ambiguous', 'typo', 'bad_explanation', 'other'];
  int _selected = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  Future<void> _submit() async {
    final q = ref.read(practiceSessionProvider).question;
    if (q == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(practiceRepositoryProvider).createCorrection(
            questionId: q.id,
            reason: _codes[_selected],
            comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: Text(context.s('exp_rc_h'))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 30),
              const Text('⏳', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(context.s('exp_rc_sent_h'),
                  style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 8),
              Text(context.s('exp_rc_sent_p'), textAlign: TextAlign.center, style: TextStyle(color: t.muted)),
              const Spacer(),
              PrimaryButton(label: context.s('exp_back'), onPressed: () => context.pop()),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.s('exp_rc_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.s('exp_rc_p'), style: TextStyle(color: t.muted)),
          const SizedBox(height: 10),
          for (int i = 0; i < _reasons.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selected = i),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _selected == i ? t.brand : t.line, width: 1.5),
                    color: _selected == i ? t.brand.withOpacity(.05) : null,
                  ),
                  child: Row(children: [
                    Icon(_selected == i ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18, color: _selected == i ? t.brand : t.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.s(_reasons[i]), style: const TextStyle(fontSize: 13))),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: InputDecoration(hintText: context.s('exp_rc_comment')),
          ),
          const SizedBox(height: 10),
          SoftCard(
            background: AppColors.bronze.withOpacity(.12),
            borderColor: AppColors.bronze,
            child: Row(children: [
              const MedalCoin('bronze', size: 24),
              const SizedBox(width: 8),
              const Expanded(child: Text('Si el error se confirma, recibirás 250 medallas de bronce.', style: TextStyle(fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: context.s('exp_rc_send'), onPressed: _busy ? null : _submit),
        ]),
      ),
    );
  }
}
