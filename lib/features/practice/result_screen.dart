import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/medal_coin.dart';
import '../../providers/practice_session.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  Future<void> _next(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(practiceSessionProvider.notifier).loadNext();
      router.pushReplacement('/practice/question');
    } on ApiException catch (e) {
      if (e.isQuotaExhausted) {
        router.pushReplacement('/paywall');
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(practiceSessionProvider);
    final q = session.question;
    final r = session.result;
    final t = context.tokens;
    if (q == null || r == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('—')));
    }
    final correctIdx = r.correctAnswer.isNotEmpty ? r.correctAnswer.codeUnitAt(0) - 65 : -1;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Center(
            child: Column(children: [
              Text(r.correct ? '✅' : '❌', style: const TextStyle(fontSize: 42)),
              Text(r.correct ? context.s('res_ok') : context.s('res_no'),
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: r.correct ? AppColors.exito : AppColors.error)),
            ]),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < q.options.length; i++)
            _ResultOption(
              letter: String.fromCharCode(65 + i),
              text: q.options[i],
              isCorrect: i == correctIdx,
              isWrongChoice: i == session.selectedIndex && !r.correct,
            ),
          const SizedBox(height: 10),
          SoftCard(child: Text(r.shortExplanation, style: TextStyle(fontSize: 12, color: t.muted))),
          if (r.correct && r.medalAmount > 0) ...[
            const SizedBox(height: 8),
            SoftCard(
              borderColor: AppColors.bronze,
              background: AppColors.bronze.withOpacity(.12),
              child: Row(children: [
                MedalCoin(r.medalTier ?? 'bronze', size: 28),
                const SizedBox(width: 9),
                Text('+${r.medalAmount} ${context.s('med_bronze')}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ],
          if (r.cohortPercentile != null) ...[
            const SizedBox(height: 8),
            SoftCard(
              background: AppColors.exito.withOpacity(.08),
              borderColor: AppColors.exito,
              child: Text('⚡ Más rápido que el ${r.cohortPercentile}% de tu cohorte.',
                  style: const TextStyle(fontSize: 12)),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => context.push('/practice/explanation'),
              child: Text('📖 ${context.s('see_full')}')),
          const SizedBox(height: 6),
          OutlinedButton(
              onPressed: () => context.push('/share-group'), child: Text(context.s('grp_share_to'))),
          const SizedBox(height: 6),
          PrimaryButton(label: context.s('next_q'), onPressed: () => _next(context, ref)),
        ]),
      ),
    );
  }
}

class _ResultOption extends StatelessWidget {
  const _ResultOption({required this.letter, required this.text, required this.isCorrect, required this.isWrongChoice});
  final String letter, text;
  final bool isCorrect, isWrongChoice;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Color border = t.line, bg = Colors.transparent, key = Colors.transparent, keyText = t.ink;
    if (isCorrect) {
      border = AppColors.exito;
      bg = AppColors.exito.withOpacity(.08);
      key = AppColors.exito;
      keyText = Colors.white;
    } else if (isWrongChoice) {
      border = AppColors.error;
      bg = AppColors.error.withOpacity(.06);
      key = AppColors.error;
      keyText = Colors.white;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border, width: 1.5), color: bg),
        child: Row(children: [
          CircleAvatar(radius: 12, backgroundColor: key, child: Text(letter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: keyText))),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      ),
    );
  }
}
