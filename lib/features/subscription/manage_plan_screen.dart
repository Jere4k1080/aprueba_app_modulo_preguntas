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

class ManagePlanScreen extends ConsumerWidget {
  const ManagePlanScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(subscriptionRepositoryProvider).cancel();
      ref.invalidate(subscriptionProvider);
      messenger.showSnackBar(SnackBar(content: Text(context.s('mng_cancelled'))));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(subscriptionProvider);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('mng_h'))),
      body: SafeArea(
        child: AsyncValueView<Subscription?>(
          value: sub,
          onRetry: () => ref.invalidate(subscriptionProvider),
          data: (s) {
            if (s == null) {
              return ListView(padding: const EdgeInsets.all(16), children: [
                SoftCard(child: Text(context.s('set_free'))),
                const SizedBox(height: 12),
                PrimaryButton(label: context.s('up_cta'), onPressed: () => context.push('/paywall')),
              ]);
            }
            return ListView(padding: const EdgeInsets.all(16), children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(context.s('mng_current'), style: TextStyle(fontSize: 11, color: t.muted)),
                  Text('${s.plan.toUpperCase()} · ${s.billingCycle}', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 16)),
                  if (s.currentPeriodEnd != null) ...[
                    const Divider(height: 18),
                    Row(children: [Text(context.s('mng_next')), const Spacer(), Text(s.currentPeriodEnd!)]),
                  ],
                  if (s.cardLast4 != null) ...[
                    const Divider(height: 18),
                    Row(children: [Text(context.s('mng_method')), const Spacer(), Text('${s.cardBrand ?? ''} •••• ${s.cardLast4}')]),
                  ],
                ]),
              ),
              if (s.cancelAtPeriodEnd) ...[
                const SizedBox(height: 8),
                Tag(context.s('mng_cancelled'), variant: 'w'),
              ],
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => context.push('/paywall'), child: Text(context.s('mng_change'))),
              const SizedBox(height: 6),
              if (!s.cancelAtPeriodEnd)
                TextButton(onPressed: () => _cancel(context, ref), child: Text(context.s('mng_cancel'))),
            ]);
          },
        ),
      ),
    );
  }
}
