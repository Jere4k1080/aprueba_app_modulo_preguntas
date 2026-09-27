import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';
import '../../providers/practice_session.dart';
import 'quota_unlock_screen.dart';

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
    // Si la ruta se abre sin pedir antes la pregunta, como al recargar la app
    // web, se pide aquí.
    final session = ref.read(practiceSessionProvider);
    if (session.question == null && session.error == null && !session.loading) {
      Future.microtask(ref.read(practiceSessionProvider.notifier).loadNext);
    }
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
    final error = session.error;
    // Regla de negocio 8: la cuota base lleva al desbloqueo, no a un error.
    if (error != null && error.isQuotaBaseReached) return const QuotaUnlockScreen();
    if (error != null) return Scaffold(appBar: AppBar(), body: _NoQuestion(error));
    final q = session.question;
    if (q == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final current = q.progressCurrent;
    // Con un plan ilimitado total llega en null y no hay "de N" (ADR-73).
    final total = q.progressTotal;
    final quota = session.quota;
    return Scaffold(
      appBar: AppBar(
        title: Text(current == null
            ? context.s('today')
            : total == null
                ? context.s('q_n').replaceFirst('{n}', '$current')
                : context.s('q_of').replaceFirst('{n}', '$current').replaceFirst('{t}', '$total')),
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              // unlimited va antes que max, que vale 0 en un plan ilimitado (ADR-66).
              if (quota != null)
                Text('${context.s('quota')}: ${quota.unlimited ? '∞' : '${quota.used}/${quota.max}'}',
                    style: TextStyle(fontSize: 12, color: context.tokens.muted)),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 18),
              const SizedBox(width: 4),
              Text(_clock, style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Montserrat')),
            ]),
          ),
          if (current != null && total != null && total > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProgressBar(value: current / total),
            ),
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

/// Lo que ve el alumno cuando no hay pregunta. Cada error de negocio es un
/// estado propio, y "sin conexión" es solo la falta de red (regla de negocio 8).
class _NoQuestion extends ConsumerWidget {
  const _NoQuestion(this.error);
  final ApiException error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void retry() => ref.read(practiceSessionProvider.notifier).loadNext();
    void chooseTests() => _chooseTests(context, ref);
    final (IconData icon, String? title, String body, String action, VoidCallback onAction) = switch (error) {
      ApiException(isQuotaExhausted: true) =>
        (Icons.hourglass_bottom, context.s('cap_h'), context.s('cap_p'), context.s('choose'), () => context.push('/paywall')),
      ApiException(needsTests: true) =>
        (Icons.checklist, context.s('sel_h'), context.s('q_tests_p'), context.s('q_choose_tests'), chooseTests),
      ApiException(isNoQuestions: true) =>
        (Icons.inbox_outlined, context.s('q_empty_h'), context.s('q_empty_p'), context.s('q_choose_tests'), chooseTests),
      ApiException(isNetwork: true) => (Icons.cloud_off, null, context.s('auth_err_network'), context.s('retry'), retry),
      _ => (Icons.error_outline, null, error.message, context.s('retry'), retry),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 40),
          if (title != null) ...[
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
          ],
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: context.tokens.muted)),
          const SizedBox(height: 16),
          PrimaryButton(label: action, onPressed: onAction),
          TextButton(
            onPressed: () => context.go('/home'),
            child: Text(error.isQuotaExhausted ? context.s('free_back') : context.s('later')),
          ),
        ]),
      ),
    );
  }
}

/// Elegir pruebas sin salir de la práctica, con GET /tests y PUT
/// /me/preferences (ADR-74). La elección del onboarding sigue con la creación
/// de la cuenta y no sirve a un alumno con sesión.
Future<void> _chooseTests(BuildContext context, WidgetRef ref) async {
  final saved = await showModalBottomSheet<bool>(context: context, builder: (_) => const _TestsSheet());
  if (saved == true) await ref.read(practiceSessionProvider.notifier).loadNext();
}

class _TestsSheet extends ConsumerStatefulWidget {
  const _TestsSheet();
  @override
  ConsumerState<_TestsSheet> createState() => _TestsSheetState();
}

class _TestsSheetState extends ConsumerState<_TestsSheet> {
  Set<String>? _chosen;
  bool _busy = false;

  Future<void> _save(Preferences prefs, Set<String> chosen) async {
    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).setPreferences(prefs.copyWith(selectedTests: chosen.toList()));
      ref.invalidate(preferencesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(preferencesProvider);
    final catalog = ref.watch(testsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AsyncValueView<Preferences>(
          value: preferences,
          onRetry: () => ref.invalidate(preferencesProvider),
          data: (prefs) => AsyncValueView<List<TestInfo>>(
            value: catalog,
            onRetry: () => ref.invalidate(testsProvider),
            data: (tests) {
              final chosen = _chosen ??= {...prefs.selectedTests};
              return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(context.s('sel_h'),
                    style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                Text(context.s('sel_p'), style: TextStyle(color: context.tokens.muted)),
                const SizedBox(height: 12),
                // Una prueba sin preguntas no se ofrece: el backend la rechaza (regla de negocio 6).
                Wrap(children: [
                  for (final test in tests.where((t) => t.hasQuestions))
                    SelectChip(
                      label: test.label,
                      selected: chosen.contains(test.id),
                      color: colorFromHex(test.color),
                      onTap: () => setState(() {
                        if (!chosen.remove(test.id)) chosen.add(test.id);
                      }),
                    ),
                ]),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: context.s('next'),
                  onPressed: chosen.isEmpty || _busy ? null : () => _save(prefs, chosen),
                ),
              ]);
            },
          ),
        ),
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
            color: selected ? t.brand.withValues(alpha: .06) : null,
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
