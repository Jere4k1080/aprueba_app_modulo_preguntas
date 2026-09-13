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

class BenefitsScreen extends ConsumerWidget {
  const BenefitsScreen({super.key});

  Future<void> _redeem(BuildContext context, WidgetRef ref, Benefit b) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(medalsRepositoryProvider).redeem(b.id);
      ref.invalidate(benefitsProvider);
      ref.invalidate(meProvider);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(r.benefit),
            content: Text('Tu cupón: ${r.couponCode}'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefits = ref.watch(benefitsProvider);
    final wallet = ref.watch(meProvider).valueOrNull?.medals.platinum ?? 0;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('med_benefits_title'))),
      body: SafeArea(
        child: AsyncValueView<List<Benefit>>(
          value: benefits,
          onRetry: () => ref.invalidate(benefitsProvider),
          data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
            Text(context.s('med_benefits_sub'), style: TextStyle(color: t.muted)),
            const SizedBox(height: 10),
            SoftCard(
              background: AppColors.platinum.withOpacity(.14),
              borderColor: AppColors.platinum,
              child: Row(children: [
                const MedalCoin('platinum', size: 40),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$wallet / 5', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF7C3AED))),
                  Text('Platino para desbloquear', style: TextStyle(fontSize: 11, color: t.muted)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            for (final b in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SoftCard(
                  child: Row(children: [
                    const Icon(Icons.card_giftcard, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(b.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(b.description, style: TextStyle(fontSize: 11, color: t.muted)),
                        const SizedBox(height: 4),
                        b.unlocked
                            ? const Tag('✅ Desbloqueado', variant: 'g')
                            : Tag('🔒 ${context.s('med_locked_need')}'),
                      ]),
                    ),
                    if (b.unlocked && wallet >= b.costPlatinum)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.platinum, foregroundColor: Colors.white, minimumSize: const Size(0, 36)),
                        onPressed: () => _redeem(context, ref, b),
                        child: Text(context.s('med_unlock_benefit'), style: const TextStyle(fontSize: 11)),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
