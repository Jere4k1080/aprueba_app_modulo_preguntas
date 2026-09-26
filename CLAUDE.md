## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).

# CLAUDE.md

Instrucciones para Claude Code en este repositorio.

## Qué es esto

Módulo de preguntas de la app móvil **Aprueba**, producto de la empresa **Alloxentric**. Proyecto de Título (Capstone) del Grupo 9, PTY4614, sección CAPSTONE_002D, Duoc UC San Bernardo.

No confundas los nombres: Alloxentric es la empresa, Aprueba es el producto. Ese error ya apareció en documentos entregados.

**Equipo y roles XP**

| Integrante | Rol | Foco |
|---|---|---|
| Martin Espinoza Morales | Coach y Tracker | Prácticas, velocidad, comunicación con la empresa, cliente delegado |
| Jeremías Fernández Millacura | Programador | Servicios de backend y modelo de datos |
| Sebastián Acevedo Araya | Programador | Cliente móvil y capa de presentación |

**Metodología:** Extreme Programming, metodología única. No es Scrum ni un híbrido. Diez iteraciones semanales agrupadas en tres entregas funcionales. Si encuentras vocabulario de Scrum en el código o en la documentación, corrígelo: sprint pasa a iteración, Scrum Master a Coach, Product Backlog a lista de historias de usuario.

---

## Tu rol

Buena parte del trabajo de este repositorio la producen otros agentes. **Tu función principal es auditar y corregir ese trabajo**, no solo generar más.

Cuando te pidan revisar algo, o cuando abras el repositorio después de que otro agente haya trabajado, aplica el checklist de auditoría de más abajo antes de hacer nada más.

Cuando encuentres un problema, no lo arregles en silencio: dilo, explica por qué es un problema y recién entonces corrígelo.

Cuando algo esté bien, dilo también. Un informe de auditoría que solo lista defectos no permite distinguir lo revisado de lo no revisado.

---

## Reglas que no se negocian

Estas se verifican en toda auditoría. Un incumplimiento se reporta siempre, aunque no te lo hayan preguntado.

**1. La respuesta correcta nunca llega al cliente antes de tiempo.**
Es la regla de integridad del producto. Se cumple en cinco lugares y hay que verificar los cinco:
- `sanitize_question()` en `backend/app/services/questions.py` elimina `correctAnswer` antes de emitir
- `GET /practice/next` y `GET /questions/{id}` no la incluyen
- `Question.correctAnswer` es nullable en el modelo Dart
- `CachedQuestions.correctAnswer` entra en nulo y solo se puebla tras responder, verificado en `test/drift_integrity_test.dart`
- `firestore.rules` niega al cliente toda lectura y escritura, así que nadie puede leer `questions` directo desde Firestore y saltarse `sanitize_question()`. Decidido en ADR-21

Si un cambio toca cualquiera de esos puntos, verifica que la regla siga en pie.

**2. Ningún secreto se versiona.**
Antes de cualquier commit:

```bash
grep -rIl -E "serviceAccount|private_key|BEGIN PRIVATE KEY|sk_live|pk_live|AIza" . \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=flutter --exclude-dir=build --exclude-dir=.venv \
  --exclude-dir=.dart_tool --exclude=firebase_options.dart --exclude=google-services.json --exclude=GoogleService-Info.plist
```

`--exclude-dir=.venv` deja fuera el entorno de Python del backend. Sin esa opción, las librerías de Google instaladas ahí dan decenas de coincidencias con `private_key`.

Los archivos de cliente de Firebase se excluyen porque su `apiKey` empieza con `AIza` y es pública por diseño: identifica el proyecto y viaja dentro de la app, pero no da acceso a los datos, que protegen `firestore.rules` y la verificación del token en la API (ADR-42). `.dart_tool` se excluye porque una compilación web copia esa `apiKey` a `main.dart.js`. La cuenta de servicio del backend sí es secreta: solo llega por `FIREBASE_SERVICE_ACCOUNT_BASE64` y nunca se versiona.

Con esas exclusiones la búsqueda devuelve cuatro archivos esperados, sin secretos: `.gitignore` y este `CLAUDE.md`, que nombran los patrones; `lib/core/config/app_config.dart`, por un comentario que menciona `pk_live`, y `backend/tests/test_core.py`, que genera una llave RSA en memoria con `rsa.generate_private_key` para firmar tokens de prueba. Cualquier otro resultado se revisa antes de commitear.

Las credenciales van por `--dart-define` en el cliente y por variables de entorno en el backend. `.env.example` no lleva valores reales.

**3. Nada va directo a `main`.**
Una rama por tarea con nombre `feature/<descripción>`, un pull request por rama, y revisión de otro integrante antes de fusionar. Si te piden commitear a `main`, adviértelo antes de hacerlo.

**4. No subas versiones de dependencias para que algo compile.**
Ni en `pubspec.yaml` ni en `backend/requirements.txt` o `backend/requirements-dev.txt`. Si hay un conflicto de versiones, repórtalo y detente.

**5. Toda decisión tomada sin información suficiente va a `docs/bitacora_decisiones.md`**, con la alternativa descartada y el motivo. La bitácora es la mitigación declarada de la práctica XP de cliente en sitio, que el equipo no puede cumplir. No es opcional.

**6. No crees modelos de Firestore en el cliente Flutter.**
Decidido en ADR-03. La app habla con la API, no con la base de datos. Los esquemas de las colecciones viven en `docs/diccionario_de_datos.md`, y `seed/README.md` muestra lo que carga el seed.

**7. Ningún agente configura identidad de git en `.git/config`.**
Los commits llevan la identidad global de quien opera el agente, la de `git config --global user.name` y `user.email`. Antes del primer commit, `git var GIT_AUTHOR_IDENT` tiene que mostrar a esa persona. Si `.git/config` trae una sección `[user]`, se reporta y se quita. Una identidad local dejó 35 commits de `main` a nombre de "Audit Sim" (ADR-56), y Vercel, en plan Hobby, bloquea los despliegues de commits cuyo autor no es el dueño del equipo.

---

## Límites de alcance

Dentro del alcance: `lib/features/practice/` y los servicios del backend que lo alimentan. Seis pantallas y trece servicios.

**Fuera del alcance, aunque esté en el repositorio:** onboarding, registro y autenticación, home, medallas y canjes, grupos, comunidad, tutores, muro de pago, ajustes y notificaciones. Ese código es del cliente y no se toca.

Excepción: si `flutter analyze` reporta una advertencia en código fuera del módulo, se corrige, porque el analizador limpio es criterio de terminado. Hazlo en un commit separado para que el límite del alcance quede visible en el historial.

Cambio autorizado: el 23/09/2026 Alloxentric autorizó tocar lo necesario del login para pasar a Firebase Auth y sacar la verificación por SMS. Los archivos tocados y el motivo de cada uno están en ADR-41. Siguen fuera del alcance y sin tocar la pantalla de registro (`register_screen.dart`), el login social, el olvido de contraseña y su restablecimiento. Del registro cambiaron el router, que salta los pasos de teléfono, y `PhoneAuthService`.

`flutter analyze` reporta 38 avisos informativos y ninguna advertencia. 28 son deprecaciones de `withOpacity` y no se tocan, decidido en ADR-08. 14 de los 38 están en `lib/features/practice/`, 10 de ellos de `withOpacity`.

---

## Comandos

```bash
# Cliente
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # obligatorio, genera database.g.dart
flutter analyze                                            # debe salir sin advertencias
flutter test                                               # todas en verde
flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# Backend (en Windows el intérprete es .venv/Scripts/python.exe)
npx --yes firebase-tools emulators:start --only firestore --project demo-aprueba   # emulador, desde la raíz
cd backend
uv venv --python 3.12 .venv
uv pip install --python .venv -r requirements-dev.txt
.venv/bin/python -m app.seed     # datos de prueba; pide SEED_DEMO_UID y SEED_DEMO_NEW_UID en .env
.venv/bin/python -m app          # API en /api/v1
.venv/bin/python -m pytest       # 38 pruebas; sin emulador, 36 y 2 omitidas

# Verificador sin SDK de Flutter
python3 tool/check_static.py .
```

`build_runner` es obligatorio: `database.g.dart` no está versionado y sin él el proyecto no compila.

`tool/check_static.py` revisa el código Dart sin el SDK: entradas de l10n, `Endpoints`, imports relativos, símbolos retirados, delimitadores y providers. `tool/check_models.py` no se corre. Compara `models.dart` con un volcado que genera `dump_payloads.js`, un script del backend Node del cliente (`aprueba_student_web`) que no está en este repositorio, y la mayoría de sus casos son de tutores, chat y onboarding, fuera del alcance.

---

## Checklist de auditoría

Cuando revises trabajo hecho por otro agente, recorre esta lista y reporta el resultado de cada punto.

**Verificaciones automáticas**
- [ ] `flutter analyze` sin advertencias
- [ ] `flutter test` en verde, y el número de pruebas no bajó
- [ ] `python -m pytest` en `backend/` en verde con el emulador activo, y el número de pruebas no bajó
- [ ] `build_runner` regenera sin conflictos
- [ ] La búsqueda de secretos no arroja nada fuera de los cuatro archivos esperados de la regla 2

**Integridad del dominio**
- [ ] La respuesta correcta sigue protegida en los cinco puntos
- [ ] Las reglas de Firestore coinciden con lo que dice `docs/diccionario_de_datos.md`
- [ ] Los índices de `firestore.indexes.json` respaldan consultas del módulo o los declara el modelo de datos de la empresa
- [ ] Las respuestas del backend respetan el envelope `{data, error, meta}` y el catálogo de errores
- [ ] Los errores de negocio se traducen a estados de interfaz, no a mensajes genéricos

**Proceso**
- [ ] El trabajo está en una rama, no en `main`
- [ ] Hay un pull request abierto
- [ ] Las decisiones nuevas quedaron en la bitácora
- [ ] El alcance respetado: no se tocó código del cliente fuera del módulo sin motivo
- [ ] Los commits nuevos llevan la identidad global de quien opera el agente y `.git/config` no tiene sección `[user]` (regla 7)

**Coherencia documental**
- [ ] Vocabulario XP, sin residuos de Scrum
- [ ] Alloxentric como empresa, Aprueba como producto
- [ ] El README de la raíz es el del equipo, no el heredado del cliente
- [ ] Lo que afirma la documentación coincide con lo que hace el código

**Advertencia sobre ramas paralelas.** Si hay varios pull requests abiertos creados desde `main` por separado, revisa si tocan los mismos archivos. `docs/bitacora_decisiones.md` y `README.md` son los que más chocan. Reporta el orden de fusión recomendado antes de que alguien fusione a ciegas.

---

## Arquitectura

```
lib/
  core/        tema, i18n, router, red (Dio), storage seguro, config
  data/
    local/     Drift — caché y preferencias
    models/    modelo lógico de la API
    repositories/  uno por dominio, patrón API + caché
    services/  integraciones externas
  features/
    practice/  ← nuestro módulo: 6 pantallas
  providers/   wiring de Riverpod

backend/          Python 3.12 + FastAPI
  app/
    main.py       create_app(): middlewares, CORS, manejo de errores, routers
    core/         config, envelope, catálogo de errores, i18n, verificación del token de Firebase, paginación
    db/           cliente de Firestore, Firebase Admin y nombres de colecciones
    routers/      endpoints bajo /api/v1
    schemas/      modelos Pydantic en camelCase
    services/     lógica de negocio, incluye sanitize_question()
    seed/         carga de datos de prueba y banco en JSON
  tests/          pytest

docs/
  bitacora_decisiones.md    ADR del proyecto
  diccionario_de_datos.md   entregable EDT 1.3.2.1
seed/README.md              lo que carga el seed, con ejemplos
```

**Flujo de datos:** UI → provider → repositorio → `ApiClient` (Dio). La interfaz nunca habla directo con la red. Cada lectura se escribe en Drift y, ante error de red, el repositorio sirve la última copia.

**Sesión:** Firebase Auth con correo y contraseña. La app envía en `Authorization` el ID token de Firebase, que dura una hora y que el SDK de Firebase renueva solo. El backend lo valida con `verify_id_token` de `firebase-admin` en `backend/app/core/deps.py`, y no emite ni renueva tokens. Ante un 401, `ApiClient` pide un token nuevo con `getIdToken(forceRefresh: true)` y reintenta una sola vez. Si el reintento vuelve a dar 401, o Firebase ya no tiene usuario, llama a `AuthController.logout()`, que cierra la sesión de Firebase y borra la caché de Drift. Después el router redirige al inicio. Decidido en ADR-40.

---

## Reglas de negocio

1. La cuota diaria base sale de `plans/{plan}.limits.qDay`, y 0 es ilimitado (ADR-64). Declarar colegio suma 5 y declarar región suma 5, con tope de 20; esos tres valores son constantes de `backend/app/core/config.py`. Cada bonificación se reclama una sola vez. Reinicio diario. El seed da `qDay` 10 al plan `free`, como dice esta regla. El ejemplo de la administración trae 20, y eso va en la consulta a Max.
2. La respuesta correcta no viaja al cliente antes de que el estudiante responda.
3. Medallas de bronce: las de cada respuesta correcta salen de `plans/{plan}.badges.correct`. Cada desbloqueo de cuota da 1, fijado en `UNLOCK_MEDALS`. Una recorrección confirmada da 250, y los otorga la administración al aprobar, no el estudiante al enviar. La medalla por ingreso diario (`badges.login`) es de un módulo fuera del alcance (ADR-68). Cada movimiento va a `medalTransactions` y suma en `users.medalWallet` y `badgesTotal` en la misma transacción (ADR-59).
4. `cohortPercentile` compara la velocidad del estudiante contra su cohorte. Lo calcula el backend al responder con el histograma de `questions.stats` (ADR-63). Firestore no hace agregaciones económicas en consulta.
5. El modo facsímil requiere que el plan incluya la funcionalidad `mock_mode` del catálogo `features` de la consola (ADR-70); `random` es el modo libre. Las recorrecciones no dependen del plan.
6. Las materias que no son PAES llegan con `hasQuestions: false`.
7. Dificultad de `d1` a `d4`. El estudiante solo recibe preguntas de las pruebas que seleccionó.
8. Los errores de negocio se traducen a estados de interfaz. Alcanzar la cuota base lleva a la pantalla de desbloqueo, no a un error.

**Errores propios del módulo:** `QUOTA_BASE_REACHED` 422, `QUOTA_DAILY_LIMIT` 422, `NO_QUESTIONS_AVAILABLE` 404, `ALREADY_ANSWERED` 409, `INVALID_OPTION` 400, `BONUS_ALREADY_CLAIMED` 409, `QUOTA_MAX_REACHED` 422, `CORRECTION_ALREADY_OPEN` 409, `FORMAT_REQUIRES_PLAN` 422.

---

## Decisiones ya tomadas

Están en `docs/bitacora_decisiones.md`. No las vuelvas a discutir salvo que encuentres evidencia nueva; si la encuentras, dilo antes de cambiar nada.

- **ADR-01** `corrections` es colección raíz con `userId`. Lo que decía de `answers` y `medalLedger` quedó sustituido por ADR-60 y ADR-59
- **ADR-02** `answers` y `corrections` son inmutables para el cliente: solo create, sin update ni delete
- **ADR-03** Sin modelos de Firestore en el cliente Flutter
- **ADR-04** `Question.correctAnswer` es nullable
- **ADR-05** `potentialReward` exige la estructura `{amount}` en el contrato de la API; nada de parseo tolerante que oculte defectos del backend. En Firestore ya no se guarda (ADR-61)
- **ADR-08** Se resuelven las advertencias del analizador; los avisos de deprecación heredados no se tocan
- **ADR-09** Exclusión de preguntas respondidas mediante `users/usr_<UID>/state/practice` con `answeredQuestionIds`
- **ADR-11** Reinicio de cuota configurable por variables de entorno
- **ADR-12** Sanitización centralizada de `correctAnswer` en la capa de servicios
- **ADR-30** Backend en Python 3.12 con FastAPI, por decisión de la contraparte. Sus convenciones vienen del backend de administración de Max (ADR-31)
- **ADR-40** Autenticación con Firebase Auth, por decisión de la contraparte. El backend verifica el ID token con `firebase-admin` y no tiene JWT propio ni refresh token. Reemplaza ADR-20 y ADR-38
- **ADR-43** `verify_id_token` sin revisar revocación. El retraso de hasta una hora en rechazar un token revocado queda cubierto cuando se implementen el rechazo de usuarios suspendidos y la comprobación de `sessionsRevokedAt` (ADR-65)
- **ADR-49**, en la parte del proyecto local, con el ajuste del 2026-09-25: en local Firestore usa el emulador con el proyecto `demo-aprueba` (`FIRESTORE_EMULATOR_PROJECT_ID`), y `FIREBASE_PROJECT_ID` lleva el ID real, `aprueba-app-modulo-preguntas`, solo para validar tokens de Firebase Auth
- **ADR-56** Los 35 commits de "Audit Sim" en `main` no se reescriben. Los agentes commitean con la identidad global de quien los opera (regla 7)
- **ADR-57** El modelo sigue a la administración donde ella define una colección o un campo, y al modelo de datos de junio y su extensión del generador donde no. Decidido por la contraparte
- **ADR-58** El ID de `users` es `usr_` más el UID de Firebase, porque la consola valida ese prefijo
- **ADR-59** Las medallas se mueven en `medalTransactions`, con IDs `mtx_*`, en la misma transacción que actualiza `users.medalWallet` y `badgesTotal`. Reemplaza a `users/{uid}/medalLedger`
- **ADR-60** `answers` es subcolección de `users`: `users/usr_<UID>/answers`
- **ADR-61** `corrections` tiene la forma que lee la cola de la consola, con IDs `cor_*`
- **ADR-62** `questions` usa IDs `qst_*` y los campos del generador. Solo se sirven preguntas `published`, y `published` implica `approved`
- **ADR-63** Percentil de cohorte con el histograma de `questions.stats`, actualizado en la transacción de responder. Sustituye a ADR-10 y ADR-23
- **ADR-64** La cuota base sale de `plans/{plan}.limits.qDay` y las medallas por acierto de `badges.correct`. Los bonos, el tope y la medalla por desbloqueo son constantes del backend. El seed da `qDay` 10 a `free`
- **ADR-65**, en la parte que decidió el equipo: un token con `auth_time` anterior a `sessionsRevokedAt` da 401, en la misma lectura de `users` que hacen el alta y el control de suspendidos
- **ADR-66** El backend crea `users/usr_<UID>` en la primera petición autenticada, solo con los campos de la administración y los del módulo. `GET /me` entrega `quota.unlimited`. El seed crea las cuentas de demostración con la misma función, `new_user()`
- **ADR-67** `reason` guarda el comentario del alumno, o la etiqueta en español del código si no hay comentario. El código va en `reasonCode`
- **ADR-68** El backend actualiza `lastActivityAt` en la primera petición de cada día. La racha y la medalla por ingreso diario quedan fuera del alcance, igual que `activity`
- **ADR-70** El modo facsímil depende de que el plan incluya la funcionalidad `mock_mode`. Las recorrecciones no dependen del plan

Las ADR-09 a ADR-12 son propuestas pendientes de ratificación por el equipo. Los tramos de ADR-63 y las decisiones menores de ADR-69 se ratifican en la sesión del equipo.

---

## Cómo escribir

La profesora guía observó que la documentación se leía como generada por inteligencia artificial. Aplica esto a todo texto que produzcas, incluidos mensajes de commit, descripciones de pull request y documentos.

Prosa directa, sin adornos. Prohibido: guiones largos, la construcción "no solo X sino Y", listas de exactamente tres elementos, y las palabras "robusto", "integral", "fundamental", "clave", "garantizar", "en el marco de", "cabe destacar", "es importante señalar", "por otro lado", "en definitiva".

Párrafos en vez de viñetas cuando el contenido lo permita. No cierres las secciones con una frase que resuma lo ya dicho. No uses negrita para enfatizar dentro de párrafos. Escribe algunas oraciones cortas.

En los documentos, usa datos concretos del proyecto —nombres de archivo, números, problemas reales— en vez de afirmaciones generales.

**Mensajes de commit:** en español, formato `tipo(ámbito): descripción en minúscula`. Sin punto final.

---

## Pendientes conocidos

Verifica si siguen abiertos antes de reportarlos. Estado revisado el 2026-09-25:

- ADR-09 a ADR-12 pendientes de ratificación
- ADR-32 a ADR-39 y ADR-44 a ADR-55 son propuestas. El equipo las ratifica después de la Entrega A, porque varias dependen de `users`. De ADR-49 ya está decidido el proyecto local
- El repositorio es público y contiene el código completo del cliente. Pendiente de confirmación con la contraparte
- Los trece servicios del módulo no están implementados. La API está desplegada en `https://aprueba-app-modulo-preguntas-api.vercel.app/api/v1`, pero solo responde `/health`
- Al desplegar el backend FastAPI hay que borrar `JWT_SECRET`, `JWT_EXPIRES_IN`, `REFRESH_TOKEN_EXPIRES_IN` y `NODE_ENV` del proyecto de Vercel de la API, porque ya nadie las lee (ADR-40)
- Los tramos de ADR-63 y las decisiones menores de ADR-69 se ratifican en la sesión del equipo. Los supuestos de ADR-65 siguen pendientes de confirmar con la empresa
- Iteración 3: `User` lee `quota.unlimited` y lo revisa antes que `quota.max`, con una prueba de la app para un plan ilimitado (ADR-66)
- Consulta a Max, por enviar: si el plan `free` lleva `qDay` 10, como dice la regla 1 y carga el seed, o 20, como trae su ejemplo (ADR-64); que su código crea `correction_confirmed` con un ID automático y el campo `by`, aunque su sección 2.8 declara `mtx_*` (ADR-59); que su confirmación de recorrecciones no baja `questions.flagCount` (ADR-61); si `uni` debe incluir `mock_mode`, que hoy solo trae `all` (ADR-70); y qué módulo lleva la racha, la medalla por ingreso diario y el registro en `activity` (ADR-68)
- Con `PHONE_VERIFICATION_ENABLED` apagada el registro no tiene salida, y el login social y el restablecimiento de contraseña llaman a rutas `/auth/*` que el backend no tiene. Falta que Alloxentric defina ese camino (ADR-41)
Ya no son pendientes: la rotación de la llave de la cuenta de servicio está cerrada. La cuenta anterior `firebase-adminsdk-fbsvc` no se pudo restaurar; la actual, con el mismo nombre, tiene una sola llave creada por el equipo, `34b4db8b`, que desde el 2026-09-25 va en `FIREBASE_SERVICE_ACCOUNT_BASE64` de production y preview de la API, y que la API toma con el despliegue automático al fusionar el #15. Las llaves `b0014dfe` y `af27835c` ya no autentican y sus JSON se borraron. El proveedor de correo y contraseña de Firebase Authentication está habilitado y hay dos cuentas de demostración, creadas desde la consola el 2026-09-24. `APP_ENV=production` existe en production y preview del proyecto de Vercel de la API desde el 2026-09-24, y la API en Node siguió respondiendo 200 en `/health` (ADR-36). La app web responde 200 en `https://aprueba-app-modulo-preguntas.vercel.app`, y `firestore.rules` niega al cliente toda lectura y escritura en el proyecto `aprueba-app-modulo-preguntas`, con las reglas activas iguales al archivo. El seed nuevo de la Entrega A está cargado en ese proyecto desde el 2026-09-26, con 68 documentos de IDs fijos. Las dos cuentas de demostración tienen su documento `users/usr_<UID>` y su nombre visible en Firebase Authentication, y no quedan documentos del seed del 2026-09-23. Los 5 índices de `firestore.indexes.json` están `READY`, y los tres del modelo anterior se borraron. Un cliente anónimo recibe 403 al leer cualquiera de sus documentos. El PR #12 está fusionado en main y backend/vercel.json ya está versionado. El 2026-09-23, la API respondió 200 en /health y el preflight de la vista previa respondió 204 con Access-Control-Allow-Origin. Era el backend Node: con FastAPI ese preflight responde 200 (ADR-39). Que las vistas previas y las URLs propias de cada despliegue pidan iniciar sesión en Vercel es la protección del proyecto, no un error.
