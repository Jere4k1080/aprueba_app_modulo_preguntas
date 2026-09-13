
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../repositories/notifications_repository.dart';

/// Permisos y registro del token push (FCM/APNs) contra POST /devices.
///
/// CONFIGURACIÓN REQUERIDA:
///  - Inicializa Firebase (Firebase.initializeApp) en main().
///  - Añade google-services.json (Android) y GoogleService-Info.plist (iOS).
///  - En iOS habilita Push Notifications y Background Modes en Xcode.
class PushService {
  PushService(this._notifications);
  final NotificationsRepository _notifications;

  final _fcm = FirebaseMessaging.instance;

  Future<void> registerForPush({String? deviceId}) async {
    try {
      final settings = await _fcm.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _fcm.getToken();
      if (token == null) return;
      final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : (kIsWeb ? 'web' : 'android');
      await _notifications.registerDevice(platform: platform, pushToken: token, deviceId: deviceId);
    } catch (e) {
      debugPrint('Registro push falló (revisa Firebase): $e');
    }
  }

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;
}
