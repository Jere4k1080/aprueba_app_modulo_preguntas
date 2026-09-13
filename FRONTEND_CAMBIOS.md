# App del alumno — alineación con el wireframe y los endpoints nuevos

Cambios sobre `aprueba_app` para consumir el backend actualizado
(`aprueba_student_web/backend`) y cubrir lo que faltaba de `Aprueba_App.html`.

Decisiones acordadas: teléfono con **Firebase Auth** (+ token de desarrollo),
catálogo **servido por la API** con respaldo local, chat por **REST + polling**,
y pestaña de **Tutores solo para planes de pago**.

---

## 1. Verificación telefónica (Firebase Auth)

- Nuevo `data/services/phone_auth_service.dart`: `sendCode` dispara el SMS con
  `verifyPhoneNumber` y `confirmCode` canjea el código por un `idToken`.
  Contempla la auto-verificación de Android, el reenvío (`forceResendingToken`) y
  un timeout de 75 s para que la pantalla no quede bloqueada en iOS.
- `AppConfig.usePhoneDevToken` (por defecto en debug/profile) envía
  `dev:+56912345678` en lugar de hablar con Firebase. Sirve para recorrer el
  onboarding completo sin configurar el proveedor de teléfono; el backend lo
  acepta con `PHONE_AUTH_ALLOW_DEV_TOKEN=true`. Para probar el camino real:

  ```bash
  flutter run --dart-define=PHONE_AUTH_DEV_TOKEN=false
  ```

- `AuthRepository`: `startPhoneVerification` → `POST /auth/phone/send-code`,
  `confirmPhoneVerification` → `POST /auth/phone/verify-code` (devuelve
  `phoneToken`), `attachPhone` → `PATCH /me/phone` para el flujo social.
- El registro ahora envía `phoneToken`, `country`, `language` y `gradeId`
  (antes mandaba `phoneVerificationToken`/`countryCode`, que el backend ignoraba).
- Los botones sociales usan `phoneVerificationRequired` de la respuesta para
  decidir si mandan al alta de teléfono.

## 2. Catálogo del onboarding servido por la API

- `data/repositories/catalog_repository.dart` + `providers/catalog_providers.dart`
  consumen `GET /countries`, `GET /countries/:code/grades` y
  `GET /tests?gradeId=`.
- `features/onboarding/education_catalog.dart` pasó a ser **solo respaldo** para
  cuando la API no responde, con los mismos ids del backend.
- Se normalizó el país a `UK` (el cliente usaba `GB`, que el backend rechazaba)
  y los ids `gb-*` → `uk-*`, `english-language` → `eng-lang`.
- `PUT /me/preferences` ahora persiste país, idioma y grado
  (`OnboardingNotifier.preferencesPayload()`).

## 3. Marketplace de tutores (6 pantallas + análisis)

`features/tutors/`:

| Pantalla | Ruta | Endpoints |
|---|---|---|
| Marketplace (búsqueda, filtros, orden) | `/tutors` | `GET /tutors`, `GET /tutors/featured` |
| Perfil | `/tutors/:id` | `GET /tutors/:id` |
| Todas las reseñas | `/tutors/:id/reviews` | `GET /tutors/:id/reviews` |
| Contactar | `/tutors/:id/contact` | `POST /tutors/:id/contact-requests` |
| Bandeja de chats | `/tutors/chats` | `GET /me/conversations` |
| Chat | `/tutors/chats/:id` | `GET/POST /conversations/:id/messages`, `POST .../read`, `PATCH .../contact-sharing` |
| Calificar (3 criterios) | `/tutors/:id/review` | `POST /tutors/:id/reviews` |
| Análisis de falencias | `/tutors/analysis` | `GET /me/gap-analysis` |

- Sin filtros se muestran los destacados; con filtros, el resultado de búsqueda.
- El chat refresca cada `AppConfig.chatPollInterval` (8 s) con un
  `StreamProvider.autoDispose`, así que el polling muere al cerrar la pantalla.
- El teléfono del tutor solo se muestra con consentimiento mutuo.
- Los `403 PLAN_REQUIRED` se traducen en el paywall, no en un error genérico.

## 4. Pestaña de Tutores solo para planes de pago

- El shell tiene 6 ramas; `TabScaffold` oculta la de Tutores en plan free y mapea
  el índice visible al de la rama.
- `app_router.dart` redirige `/tutors*` al paywall **solo cuando `/me` ya
  resolvió**, para no expulsar a un usuario de pago durante el arranque.
- El `routerProvider` no observa la sesión ni el plan (si lo hiciera, cada cambio
  crearía un router nuevo y la navegación volvería a `/splash`, perdiendo el paso
  de formato del alta): lee el estado dentro de `redirect` y se reevalúa con
  `refreshListenable`.

## 5. Correcciones de paso

- `features/subscription/checkout_screen.dart` estaba **truncado a mitad de una
  expresión** (el proyecto no compilaba); se completó.
- `.clamp(0, 1)` → `.clamp(0.0, 1.0)` en `common_widgets.dart` y
  `exchange_screen.dart` (devolvía `num` donde se espera `double`).
- `meProvider` ahora depende de la sesión: antes cacheaba el 401 previo al login
  y el perfil quedaba en error después de entrar.
- Piso de Flutter a `>=3.22.0` (el código ya usaba `WidgetStatePropertyAll`).

## Cómo verificar

```bash
cd aprueba_app
flutter pub get
flutter analyze
flutter test
```

Sin SDK de Flutter a mano hay dos comprobaciones auxiliares en `tool/`:

```bash
# claves l10n, endpoints, imports, símbolos retirados, delimitadores
python3 tool/check_static.py .

# modelos contra respuestas reales del backend
cd ../aprueba_student_web/backend && npm run seed
node src/seed/dump_payloads.js /tmp/payloads.json
cd ../../aprueba_app && python3 tool/check_models.py /tmp/payloads.json
```

## Pendiente

- Faltan `google-services.json` / `GoogleService-Info.plist` y habilitar el
  proveedor de teléfono en la consola de Firebase para el flujo real de SMS.
- No hay app del tutor: sus mensajes entran por seed o desde la consola admin.
- Las asignaturas escolares (no PAES) llegan con `hasQuestions: false`; la
  práctica sigue sirviendo solo pruebas con banco cargado.
