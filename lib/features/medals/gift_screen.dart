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

class GiftScreen extends ConsumerStatefulWidget {
  const GiftScreen({super.key});
  @override
  ConsumerState<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends ConsumerState<GiftScreen> {
  final Map<String, int> _qty = {};

  Future<void> _send(GiftState g) async {
    final recipients = _qty.entries
        .where((e) => e.value > 0)
        .map((e) => (userId: e.key, amount: e.value))
        .toList();
    if (recipients.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(medalsRepositoryProvider).sendGifts(recipients);
      ref.invalidate(giftStateProvider);
      ref.invalidate(meProvider);
      setState(_qty.clear);
      messenger.showSnackBar(const SnackBar(content: Text('🎁 Regalos enviados')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftStateProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('med_gift_title'))),
      body: SafeArea(
        child: AsyncValueView<GiftState>(
          value: gifts,
          onRetry: () => ref.invalidate(giftStateProvider),
          data: (g) => Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text(context.s('med_gift_note'), style: TextStyle(color: t.muted)),
                const SizedBox(height: 10),
                SoftCard(
                  background: AppColors.bronze.withOpacity(.12),
                  borderColor: AppColors.bronze,
                  child: Row(children: [
                    const MedalCoin('bronze', size: 24),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${g.dailyUsed}/${g.dailyMax} ${context.s('med_gift_daily')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                    Text('${g.bronzeAvailable} disp.', style: const TextStyle(fontSize: 11)),
                  ]),
                ),
                const SizedBox(height: 12),
                Text('AMIGOS EN TUS GRUPOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
                const SizedBox(height: 6),
                for (final f in g.friends)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SoftCard(
                      child: Row(children: [
                        CircleAvatar(radius: 18, backgroundColor: AppColors.azul, child: Text(_initials(f.name), style: const TextStyle(color: Colors.white, fontSize: 12))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                        _Stepper(
                          value: _qty[f.userId] ?? 0,
                          onChanged: (v) => setState(() => _qty[f.userId] = v),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(label: context.s('med_gift_send'), onPressed: () => _send(g)),
            ),
          ]),
        ),
      ),
    );
  }

  String _initials(String n) {
    final parts = n.trim().split(' ');
    return (parts.first.isNotEmpty ? parts.first[0] : '') + (parts.length > 1 ? parts.last[0] : '');
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: value > 0 ? () => onChanged(value - 1) : null),
      Text('$value', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800)),
      IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => onChanged(value + 1)),
    ]);
  }
}
