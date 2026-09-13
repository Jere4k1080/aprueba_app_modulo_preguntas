import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Planes, checkout (Stripe), suscripción e historial de cobros.
class SubscriptionRepository {
  SubscriptionRepository(this._api);
  final ApiClient _api;

  Future<List<Plan>> plans() async {
    final res = await _api.get(Endpoints.plans,
        skipAuth: true,
        parse: (d) => (d as List).map((e) => Plan.fromJson((e as Map).cast<String, dynamic>())).toList());
    return res.data;
  }

  /// Crea la sesión de pago. La cabecera Idempotency-Key evita cobros dobles.
  Future<CheckoutSession> createCheckout({
    required String plan,
    required String billingCycle,
    required String idempotencyKey,
  }) async {
    final res = await _api.post(
      Endpoints.checkoutSessions,
      headers: {'Idempotency-Key': idempotencyKey},
      body: {'plan': plan, 'billingCycle': billingCycle},
      parse: (d) => CheckoutSession.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  Future<Subscription?> current() async {
    final res = await _api.get(Endpoints.meSubscription,
        parse: (d) => d == null ? null : Subscription.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Subscription> change({required String plan, required String billingCycle}) async {
    final res = await _api.post(Endpoints.subscriptionChange,
        body: {'plan': plan, 'billingCycle': billingCycle},
        parse: (d) => Subscription.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Subscription> cancel({bool immediate = false}) async {
    final res = await _api.post(Endpoints.subscriptionCancel,
        body: {'immediate': immediate},
        parse: (d) => Subscription.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }
}
