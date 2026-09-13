import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/practice_session.dart';

class QuestionScreen extends ConsumerStatefulWidget {
  const QuestionScreen({super.key});
  @override
  ConsumerState<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends ConsumerState<QuestionScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final m = _seconds ~/ 60;
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _check() async {
    final session = ref.read(practiceSessionProvider);
    if (session.selectedIndex == null) return;
    setState(() => _busy = true);
    ref.read(practiceSessionProvider.notifier).setElapsed(_seconds * 1000);
    try {
      await ref.read(practiceSessionProvider.notifier).submit();
      if (mounted) context.pushReplacement('/practice/result');
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(practiceSessionProvider);
    final q = session.question;
    final t = context.tokens;
    if (q == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final progress = (q.progressCurrent != null && q.progressTotal != null && q.progressTotal! > 0)
        ? q.progressCurrent! / q.progressTotal!
        : 0.5;
    return Scaffold(
      appBar: AppBar(
        title: Text(q.progressTotal != null
            ? 'Pregunta ${q.progressCurrent} de ${q.progressTotal}'
            : context.s('today')),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 4),
              Text(_clock, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Montserrat')),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ProgressBar(value: progress)),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (q.axis != null) Tag('${q.axis} · ${(q.difficulty ?? '').toUpperCase()}'),
              const SizedBox(height: 10),
              Text(q.statement, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (int i = 0; i < q.options.length; i++)
                _OptionTile(
                  letter: String.fromCharCode(65 + i),
                  text: q.options[i],
                  selected: session.selectedIndex == i,
                  onTap: () => ref.read(practiceSessionProvider.notifier).select(i),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PrimaryButton(
              label: context.s('check'),
              onPressed: (session.selectedIndex == null || _busy) ? null : _check,
            ),
          ),
        ]),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.letter, required this.text, required this.selected, this.onTap});
  final String letter, text;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? t.brand : t.line, width: 1.5),
            color: selected ? t.brand.withOpacity(.06) : null,
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: selected ? t.brand : Colors.transparent,
              child: Text(letter,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : t.ink)),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}
