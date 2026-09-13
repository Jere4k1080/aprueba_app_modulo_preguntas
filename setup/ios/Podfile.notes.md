# iOS — notas

- `platform :ios, '13.0'` (flutter_stripe exige iOS 13+).
- Ejecuta `cd ios && pod install` tras `flutter pub get`.
- Coloca `ios/Runner/GoogleService-Info.plist` (Firebase).
- Capabilities en Xcode: "Sign in with Apple", "Push Notifications",
  "Background Modes → Remote notifications", y Apple Pay (merchant id).
