# Android: estado de configuración del módulo

Estado al 01/10/2026. El proyecto usa Kotlin DSL: [android/app/build.gradle.kts](../../android/app/build.gradle.kts) y [android/settings.gradle.kts](../../android/settings.gradle.kts). La nota original del cliente, más abajo, habla de `build.gradle` en Groovy y no describe estos archivos.

El archivo de la app delega `compileSdk`, `minSdk` y `targetSdk` al SDK de Flutter y compila Java y Kotlin para Java 17. No fija `minSdkVersion 23` ni `compileSdkVersion 34`. La variante release todavía usa la firma de debug, así que no hay un paquete firmado para distribución.

La configuración Firebase del cliente ya existe en [android/app/google-services.json](../../android/app/google-services.json) y [lib/firebase_options.dart](../../lib/firebase_options.dart). El login del módulo usa Firebase Auth con correo y contraseña sin SMS (HU-21); push, Stripe y login social quedan fuera del alcance.

HT-06 / T-01 cubre reproducir el entorno Flutter y backend en los equipos de los tres integrantes; RNF-10 exige la misma base de código para Android, iOS y web. Los comandos vigentes están en [README.md](../../README.md).

## Nota original del cliente

En `android/app/build.gradle`:

- `minSdkVersion 23`  (flutter_stripe exige 21+; firebase_messaging y secure_storage van cómodos con 23)
- `compileSdkVersion 34` o superior
- Habilita multidex si hace falta: `multiDexEnabled true`

Firebase (push):
- Añade el plugin `com.google.gms.google-services` en `android/settings.gradle` /
  `android/app/build.gradle` y coloca `android/app/google-services.json`.

Tema (Stripe):
- En `android/app/src/main/res/values/styles.xml` usa un tema basado en
  `Theme.MaterialComponents.DayNight.NoActionBar`.
