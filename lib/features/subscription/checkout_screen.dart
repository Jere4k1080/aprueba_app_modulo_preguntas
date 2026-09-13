import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../core/widgets/common_widgets.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.planId, required this.billingCycle});
  final String planId;
  final String billingCycle;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _busy = false;

  Future<void> _pay() async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final subRepo = ref.read(subscriptionRepositoryProvider);
      final stripe = ref.read(stripeServiceProvider);
      // 1) El backend crea la sesión de pago y devuelve el clientSecret.
      final session = await subRepo.createCheckout(
        plan: widget.planId,
        billingCycle: widget.billingCycle,
        idempotencyKey: 'co_${DateTime.now().millisecondsSinceEpoch}',
      );
      // 2) Presentamos la PaymentSheet de Stripe (Apple/Google Pay o tarjeta).
      await stripe.presentPaymentSheet(
        clientSecret: session.clientSecret,
        merchantDisplayName: 'Aprueba',
      );
      // 3) El webhook activará el plan; refrescamos perfil/suscripción.
      ref.invalidate(meProvider);
      ref.invalidate(subscriptionProvider);
      ref.invalidate(quotaProvider);
      router.pushReplacement('/pay-success');
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Pago no completado: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(plansProvider).valueOrNull ?? const [];
    final plan = plans.where((p) => p.id == widget.planId).firstOrNull;
    final price = plan == null ? 0 : (widget.billingCycle == 'yearly' ? plan.priceYearly : plan.priceMonthly);
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: Text(context.s('co_h'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(context.s('co_summary'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: t.muted)),
          const SizedBox(height: 6),
          SoftCard(
            child: Column(children: [
              Row(children: [Text(context.s('co_plan')), const Spacer(), Text(plan?.name ?? widget.planId, style: const TextStyle(fontWeight: FontWeight.w700))]),
              const Divider(height: 18),
              Row(children: [Text(context.s('co_cycle')), const Spacer(), Text(widget.billingCycle == 'yearly' ? context.s('bill_yr') : context.s('bill_mo'))]),
              const Divider(height: 18),
              Row(children: [Text(context.s('co_total')), const Spacer(), Text('\$${price.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w800, color: t.brand))]),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '${context.s('co_pay')} \$${price.toStringAsFixed(0)}', icon: Icons.lock, onPressed: _busy ? null : _pay),
          const SizedBox(height: 8),
          Center(
            child: Text('🔒 ${context.s('co_secure')}',
                style: TextStyle(fontSize: 11, color: t.muted)),
          ),
        ]),
      ),
    );
  }
}
