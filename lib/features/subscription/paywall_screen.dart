import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../data/models/models.dart';
import '../../providers/data_providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  String _cycle = 'yearly';

  num _price(Plan p) => _cycle == 'yearly' ? p.priceYearly : p.priceMonthly;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: AsyncValueView<List<Plan>>(
          value: plans,
          onRetry: () => ref.invalidate(plansProvider),
          data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
            Center(
              child: Column(children: [
                const Text('🚀', style: TextStyle(fontSize: 36)),
                Text(context.s('cap_h'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 17)),
                Text(context.s('cap_p'), style: TextStyle(color: t.muted)),
              ]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line, width: 1.5)),
              child: Row(children: [
                for (final c in [('monthly', context.s('bill_mo')), ('yearly', '${context.s('bill_yr')} · ${context.s('bill_save')}')])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _cycle = c.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _cycle == c.$1 ? t.brand : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                        child: Text(c.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Montserrat', color: _cycle == c.$1 ? Colors.white : t.muted)),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  borderColor: p.popular ? t.brand : null,
                  onTap: () => context.push('/checkout', extra: {'plan': p.id, 'cycle': _cycle}),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700))),
                      if (p.popular) Tag(context.s('popular'), variant: 'g'),
                    ]),
                    const SizedBox(height: 4),
                    Text('\$${_price(p).toStringAsFixed(0)}${_cycle == 'yearly' ? context.s('yr') : context.s('mo')}',
                        style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 26, color: t.brand)),
                    for (final f in p.features) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $f', style: TextStyle(fontSize: 12, color: t.muted))),
                    const SizedBox(height: 8),
                    PrimaryButton(label: context.s('choose'), onPressed: () => context.push('/checkout', extra: {'plan': p.id, 'cycle': _cycle})),
                  ]),
                ),
              ),
            TextButton(onPressed: () => context.go('/home'), child: Text(context.s('free_back'))),
          ]),
        ),
      ),
    );
  }
}
