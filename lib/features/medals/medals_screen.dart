import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/medal_coin.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

class MedalsScreen extends ConsumerWidget {
  const MedalsScreen({super.key});

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
    return Scaffold(
      body: SafeArea(
        child: AsyncValueView<MedalWalletState>(
          value: wallet,
          onRetry: () => ref.invalidate(medalWalletProvider),
          data: (w) => ListView(padding: const EdgeInsets.all(16), children: [
            Text(context.s('med_title'), style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 10),
            for (final tier in Medals.tiers)
              _MedalRow(
                tier: tier,
                count: w.wallet.byTier(tier),
                onExchange: w.wallet.byTier(tier) >= 5 && Medals.nextTier(tier) != null
                    ? () => _exchange(context, ref, tier)
                    : null,
              ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => context.push('/medals/exchange'), child: Text('🔄 ${context.s('med_exchange_title')}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => context.push('/medals/gift'), child: Text('🎁 ${context.s('gift')}'))),
            ]),
            const SizedBox(height: 8),
            PrimaryButton(label: '🏷️ ${context.s('med_benefits_title')}', onPressed: () => context.push('/medals/benefits')),
          ]),
        ),
      ),
    );
  }
}

class _MedalRow extends StatelessWidget {
  const _MedalRow({required this.tier, required this.count, this.onExchange});
  final String tier;
  final int count;
  final VoidCallback? onExchange;
  @override
  Widget build(BuildContext context) {
    final color = AppColors.medalColor(tier);
    final next = Medals.nextTier(tier);
    final prog = next != null ? (count % 5) / 5 : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        child: Row(children: [
          MedalCoin(tier, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(context.s('med_$tier')),
                const Spacer(),
                Text('$count', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 18, color: color)),
              ]),
              if (next != null) ...[
                const SizedBox(height: 4),
                ProgressBar(value: prog, color: color, height: 6),
              ] else
                Text('5 platino = 1 beneficio', style: TextStyle(fontSize: 11, color: context.tokens.muted)),
            ]),
          ),
          if (onExchange != null) ...[
            const SizedBox(width: 8),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              onPressed: onExchange,
              child: const Text('Canjear →', style: TextStyle(fontSize: 11)),
            ),
          ],
        ]),
      ),
    );
  }
}
