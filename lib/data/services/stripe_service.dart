import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../core/config/app_config.dart';

/// Pagos con Stripe usando PaymentSheet (Apple Pay, Google Pay y tarjeta).
///
/// CONFIGURACIÓN REQUERIDA:
///  - Define STRIPE_PUBLISHABLE_KEY y STRIPE_MERCHANT_ID (Apple Pay) por
///    --dart-define.
///  - El backend crea la sesión (POST /checkout/sessions) y devuelve el
///    clientSecret; aquí solo presentamos la hoja de pago.
class StripeService {
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    Stripe.publishableKey = AppConfig.stripePublishableKey;
    Stripe.merchantIdentifier = AppConfig.stripeMerchantId;
    try {
      await Stripe.instance.applySettings();
      _initialized = true;
    } catch (e) {
      debugPrint('Stripe init falló (revisa la clave publicable): $e');
    }
  }

  /// Presenta la PaymentSheet con el clientSecret de la sesión de pago.
  /// Lanza si el usuario cancela o falla el pago.
  Future<void> presentPaymentSheet({
    required String clientSecret,
    required String merchantDisplayName,
  }) async {
    await init();
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: merchantDisplayName,
        applePay: PaymentSheetApplePay(merchantCountryCode: 'CL'),
        googlePay: const PaymentSheetGooglePay(merchantCountryCode: 'CL', testEnv: true),
        style: ThemeMode.system,
      ),
    );
    await Stripe.instance.presentPaymentSheet();
  }
}
