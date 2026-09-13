import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/medal_coin.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

class ExchangeScreen extends ConsumerWidget {
  const ExchangeScreen({super.key});

  Future<void> _exchange(BuildContext context, WidgetRef ref, String from) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(medalsRepositoryProvider).exchange(from: from);
      ref.invalidate(medalWalletProvider);
      ref.invalidate(meProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(medalWalletProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('med_exchange_title'))),
      body: SafeArea(
        child: AsyncValueView<MedalWalletState>(
          value: wallet,
          onRetry: () => ref.invalidate(medalWalletProvider),
          data: (w) => ListView(padding: const EdgeInsets.all(16), children: [
            Text('5 medallas de un nivel = 1 del siguiente. Irreversible.', style: TextStyle(color: t.muted)),
            const SizedBox(height: 12),
            for (final from in Medals.tiers.where((x) => Medals.nextTier(x) != null))
              Builder(builder: (context) {
                final to = Medals.nextTier(from)!;
                final have = w.wallet.byTier(from);
                final can = have >= 5;
                final color = AppColors.medalColor(from);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        MedalCoin(from, size: 40),
                        Column(children: [
                          Text('5 ${context.s('med_$from')} → 1 ${context.s('med_$to')}', style: TextStyle(fontSize: 12, color: t.muted)),
                          Text('${context.s('med_have')}: $have', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                        ]),
                        MedalCoin(to, size: 40),
                      ]),
                      const SizedBox(height: 8),
                      ProgressBar(value: (have / 5).clamp(0.0, 1.0), color: color, height: 6),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
                          onPressed: can ? () => _exchange(context, ref, from) : null,
                          child: Text(can ? 'Canjear 5 → 1 ${context.s('med_$to')}' : 'Faltan ${5 - have}'),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
          ]),
        ),
      ),
    );
  }
}
