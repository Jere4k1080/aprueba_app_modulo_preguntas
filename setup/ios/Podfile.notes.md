# iOS: estado de configuración del módulo

Estado al 01/10/2026. No hay un `ios/Podfile` versionado; Flutter lo genera al compilar para iOS. [ios/Runner.xcodeproj/project.pbxproj](../../ios/Runner.xcodeproj/project.pbxproj) declara `IPHONEOS_DEPLOYMENT_TARGET = 13.0`.

La configuración Firebase del cliente ya existe en [ios/Runner/GoogleService-Info.plist](../../ios/Runner/GoogleService-Info.plist) y [lib/firebase_options.dart](../../lib/firebase_options.dart). El login del módulo usa Firebase Auth con correo y contraseña sin SMS (HU-21). Las capacidades de Apple Pay, push y login social de la nota original no son tareas del módulo.

HT-06 / T-01 cubre reproducir el entorno en los equipos de los tres integrantes; RNF-10 exige una misma base Flutter para iOS, Android y web. Compilar para iOS necesita macOS y Xcode, y la firma y las capacidades de distribución no se han verificado. Los comandos generales están en [README.md](../../README.md).

## Nota original del cliente

- `platform :ios, '13.0'` (flutter_stripe exige iOS 13+).
- Ejecuta `cd ios && pod install` tras `flutter pub get`.
- Coloca `ios/Runner/GoogleService-Info.plist` (Firebase).
- Capabilities en Xcode: "Sign in with Apple", "Push Notifications",
  "Background Modes → Remote notifications", y Apple Pay (merchant id).
