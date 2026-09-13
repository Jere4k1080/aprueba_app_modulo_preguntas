# Android — ajustes de Gradle

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
