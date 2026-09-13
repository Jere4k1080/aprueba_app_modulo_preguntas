import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import 'onboarding_state.dart';

class FormatScreen extends ConsumerStatefulWidget {
  const FormatScreen({super.key});
  @override
  ConsumerState<FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends ConsumerState<FormatScreen> {
  bool _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    // Incluye país, idioma y grado: es el paso que cierra el onboarding.
    final prefs = ref.read(onboardingProvider.notifier).preferencesPayload();
    try {
      await ref.read(profileRepositoryProvider).setPreferences(prefs);
    } catch (_) {/* el onboarding continúa aunque falle la red */}
    if (!mounted) return;
    await ref.read(localPrefsProvider.notifier).setOnboardingDone(true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(onboardingProvider).preferences;
    final n = ref.read(onboardingProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.s('fmt_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _Segment(
            options: {'random': context.s('random'), 'facsim': context.s('facsim')},
            value: prefs.format,
            onChanged: n.setFormat,
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.s(prefs.format == 'random' ? 'random' : 'facsim'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(context.s(prefs.format == 'random' ? 'randomd' : 'facsimd'),
                  style: TextStyle(fontSize: 12, color: context.tokens.muted)),
              if (prefs.format == 'facsim') ...[
                const SizedBox(height: 6),
                const Tag('⭐ Premium', variant: 'w'),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Text(context.s('diff'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(context.s('diff_p'), style: TextStyle(fontSize: 12, color: context.tokens.muted)),
          const SizedBox(height: 8),
          _Segment(
            options: {'d1': context.s('d1'), 'd2': context.s('d2'), 'd3': context.s('d3')},
            value: prefs.difficulty,
            onChanged: n.setDifficulty,
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: context.s('next'), onPressed: _busy ? null : _finish),
        ]),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.options, required this.value, required this.onChanged});
  final Map<String, String> options;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.line, width: 1.5),
      ),
      child: Row(children: [
        for (final e in options.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: value == e.key ? t.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(e.value,
                    style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: value == e.key ? Colors.white : t.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}
