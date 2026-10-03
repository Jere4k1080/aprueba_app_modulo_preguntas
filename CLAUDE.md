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

Módulo de preguntas de Aprueba para iOS, Android y web, producto de Alloxentric. Proyecto de Título (Capstone) del Grupo 9, PTY4614, sección CAPSTONE_002D, Duoc UC San Bernardo.

No confundas los nombres: Alloxentric es la empresa, Aprueba es el producto. Ese error ya apareció en documentos entregados.

**Equipo y roles XP**

| Integrante | Rol | Foco |
|---|---|---|
| Max Kreimerman, Alloxentric | Cliente | Contraparte: define producto y decisiones técnicas por escrito |
| Karina Álvarez, Alloxentric | Gestora | Jefa de proyecto: seguimiento semanal y coordinación con Max |
| Eliana Mallen González, Duoc UC | Coach | Profesora guía: prácticas XP y seguimiento académico |
| Martin Espinoza Morales | Tracker y Tester | Velocidad, reflexiones de cierre y pruebas de aceptación |
| Jeremías Fernández Millacura | Programador backend | Servicios y modelo de datos |
| Sebastián Acevedo Araya | Programador frontend | Cliente Flutter y presentación |

Quien programa no acepta su propio trabajo. Martin diseña y ejecuta las pruebas de aceptación en el entorno desplegado; los programadores escriben las unitarias antes del código. Un agente no sustituye esa aceptación.

Metodología: Extreme Programming, con diez iteraciones semanales en tres entregas funcionales. El nombre adoptado es Product Backlog (lista de producto), y se conserva. Planes de iteración, criterios de terminado y reflexiones de cierre incluyen su equivalencia con artefactos de Scrum en los documentos académicos. No hagas reemplazos ciegos: Scrum puede aparecer en comparaciones o equivalencias. Usa iteración en lugar de sprint para describir el trabajo del equipo.

Fuentes vigentes al 01/10/2026: Product Backlog v2.3, Plan de entregas y planes de iteración v1.3, EDT v3.2 (55 paquetes), Carta Gantt v2.1, Registro de interesados v1.4, Enunciado de Alcance v1.2 y Product Vision v1.4. Requisitos no funcionales, Criterios de terminado, Plan de pruebas e Innovación son v1.0. También rigen las reflexiones de iteraciones 1 a 3 y T-24. El Acta de Constitución y el SRS se retiraron; los requisitos no funcionales reemplazan al SRS. Viven en el Drive del equipo, carpeta Documentacion XP.

---

## Tu rol

Buena parte del trabajo de este repositorio la producen otros agentes. Revisa su trabajo y corrige dentro del alcance autorizado. Un encargo de solo documentación no autoriza corregir el código que la revisión detecte.

Cuando te pidan revisar algo, o cuando abras el repositorio después de que otro agente haya trabajado, aplica el checklist de auditoría de más abajo antes de hacer nada más.

Cuando encuentres un problema, no lo arregles en silencio: dilo, explica por qué es un problema y recién entonces corrígelo.

Cuando algo esté bien, dilo también. Un informe de auditoría que solo lista defectos no permite distinguir lo revisado de lo no revisado.

---

## Reglas que no se negocian

Estas se verifican en toda auditoría. Un incumplimiento se reporta siempre, aunque no te lo hayan preguntado.

**1. Ni la respuesta correcta ni la explicación llegan antes de responder (RNF-02).**
Se verifican estos cinco puntos:
- `sanitize_question()` en `backend/app/services/questions.py` elimina `correctAnswer` y `explanation` antes de emitir.
- Ninguna ruta entrega esos campos antes de responder, incluidas `GET /practice/next` y `GET /questions/{id}`. `backend/tests/test_integridad.py` recorre todas las rutas y falla si alguna respuesta trae `correctAnswer` o `explanation` en cualquier nivel del JSON.
- `Question.correctAnswer` y `Question.explanation` son nullable en Dart y llegan ausentes antes de responder.
- La caché de Drift deja nulas la respuesta y la explicación al descargar y solo las completa tras responder. `test/drift_integrity_test.dart` verifica esos momentos. El cierre de sesión borra la caché.
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

En los archivos versionados hay cuatro coincidencias esperadas, sin secretos: `.gitignore` y este `CLAUDE.md`, que nombran los patrones; `lib/core/config/app_config.dart`, por un comentario que menciona `pk_live`, y `backend/tests/test_core.py`, que genera una llave RSA en memoria con `rsa.generate_private_key` para firmar tokens de prueba. La búsqueda del proyecto puede incluir cachés AST ignoradas de Graphify que derivan de esas mismas pruebas. Cualquier coincidencia adicional se revisa antes de commitear; que esté ignorada no basta para darla por segura.

Las credenciales van por `--dart-define` en el cliente y por variables de entorno en el backend. `.env.example` no lleva valores reales.

**3. Nada va directo a `main`.**
Una rama por tarea con nombre `feature/<descripción>`, un pull request por rama y aprobación en GitHub de otro integrante antes de fusionar. Si te piden commitear a `main`, adviértelo antes de hacerlo.

**4. No subas versiones de dependencias para que algo compile.**
Ni en `pubspec.yaml` ni en `backend/requirements.txt` o `backend/requirements-dev.txt`. Si hay un conflicto de versiones, repórtalo y detente.

**5. Toda decisión tomada sin información suficiente va a `docs/bitacora_decisiones.md`**, con la alternativa descartada y el motivo. La bitácora es la mitigación declarada de la práctica XP de cliente en sitio, que el equipo no puede cumplir. No es opcional.

**6. No crees modelos de Firestore en el cliente Flutter.**
Decidido en ADR-03. La app habla con la API, no con la base de datos. Los esquemas de las colecciones viven en `docs/diccionario_de_datos.md`, y `seed/README.md` muestra lo que carga el seed.

**7. Ningún agente configura identidad de git en `.git/config`.**
Los commits llevan la identidad global de quien opera el agente, la de `git config --global user.name` y `user.email`. Antes del primer commit, `git var GIT_AUTHOR_IDENT` tiene que mostrar a esa persona. Si `.git/config` trae una sección `[user]`, se reporta y se quita. Una identidad local dejó 35 commits de `main` a nombre de "Audit Sim" (ADR-56), y Vercel, en plan Hobby, bloquea los despliegues de commits cuyo autor no es el dueño del equipo.

**8. Ninguna pregunta del banco real se versiona.**
El banco real de preguntas es contenido de Alloxentric y nunca se versiona: no entra al seed, a las pruebas, a los ejemplos ni a los documentos. La empresa lo entregó en su Drive técnico, en la carpeta Aprueba, como archivos JSON por materia en las subcarpetas PAES Chile Biologia, PAES Chile Matematica y PAES Chile Verbal. Su importación está pendiente de que la empresa entregue la clasificación de cada pregunta: la prueba en Matemática, la dificultad, el eje y la habilidad. Ningún agente inventa esos datos ni escribe preguntas para reemplazar el banco real. Mientras tanto, la demo usa el banco sintético del seed, que escribió el equipo. Antes de cada commit se verifica, buscando sus textos en los archivos versionados, que ningún enunciado, alternativa ni explicación del banco real esté en el repositorio (ADR-75).

Max preguntó si el equipo puede curar el banco con IA. Sigue pendiente de decisión y sería un cambio de alcance: primero se registra como historia, se estima y se planifica. No es autorización para importar ni para cambiar el banco.

**9. Los encargos usan los IDs del Product Backlog vigente, y las pruebas de aceptación son de Martin.**

Épicas E1 a E7, características F, historias HU, historias técnicas HT, restricciones RT-01 a RT-04 y tareas T. No uses los IDs de la lista de Fase 1. HU-22 está retirada. Registra como historia el trabajo no planificado. Antes de numerar una ADR, consulta el máximo en `main` y en todos los PR abiertos. Un agente corre las pruebas automáticas, pero no ejecuta ni registra una prueba de aceptación: las diseña y ejecuta Martin sobre el entorno desplegado.

**10. Las cargas de producción provienen de `main` revisado.**

Después de cada carga se repite la prueba de aceptación, a cargo de Martin. No cargues desde una rama sin revisión. Son acuerdos de las reflexiones de cierre de las iteraciones 1 a 3, junto con planificar desde el backlog vigente, separar las historias parciales y no permitir identidades Git de agentes.

---

## Límites de alcance

Dentro del alcance: seis pantallas de `lib/features/practice/` y catorce servicios bajo `/api/v1`: los trece del contrato más `GET /me`, incorporado como HT-07. El inicio de sesión con Firebase Auth, correo y contraseña sin SMS, está dentro por autorización del cliente (HU-21). La app se entrega en iOS, Android y navegador desde una base de código (RNF-10).

Fuera del alcance: registro y restablecimiento de contraseña, onboarding, home, pantallas de medallas y canjes, grupos, comunidad, tutores, muro de pago, ajustes y notificaciones. La racha y medalla diaria por login quedan fuera; las recompensas por respuesta y desbloqueo sí pertenecen al módulo. También quedan fuera la consola, el generador, el sitio web del alumno y la landing. El sitio web del alumno es otro componente; la versión Flutter para navegador sí es plataforma del módulo. Pagos, login social y push no se intervienen.

Excepción: si `flutter analyze` reporta una advertencia en código fuera del módulo, se corrige, porque el analizador limpio es criterio de terminado. Hazlo en un commit separado para que el límite del alcance quede visible en el historial.

Cambio autorizado: el 23/09/2026 Alloxentric autorizó pasar el login a Firebase Auth y sacar SMS. ADR-41 conserva los archivos y motivos. Enunciado de Alcance v1.2 y HU-21 incorporan ese login; el registro y restablecimiento siguen fuera. Los ajustes históricos del router y de `PhoneAuthService` no amplían esa autorización.

`flutter analyze` reporta 24 avisos informativos y ninguna advertencia, todos fuera de `lib/features/practice/`. 18 son deprecaciones de `withOpacity` y no se tocan, decidido en ADR-08. Medido el 01/10/2026 sobre el código de `main` en `df925e0`, junto con 56 pruebas de Flutter en verde y pytest sin emulador con 40 aprobadas y 22 omitidas. El Plan de pruebas v1.0 registra las 62 del backend aprobadas con el emulador al cierre de la iteración 3.

## Criterios de terminado v1.0

Una historia suma velocidad solo si Martin verificó sus criterios de aceptación en el entorno desplegado y registró el resultado; las pruebas unitarias se escribieron antes del código y pasan, incluida integridad; el analizador no reporta advertencias en el módulo; ingresó por PR aprobado en GitHub por alguien distinto del autor; respeta el contrato y traduce errores de negocio a estados de interfaz; no hay secretos ni datos reales versionados y las cargas de producción provienen de `main` revisado; y las decisiones están en las bitácoras. RNF-02 exige comprobar también la explicación.

Una historia parcial no suma puntos. Su trabajo pendiente vuelve a planificarse. La velocidad registrada de las iteraciones 1, 2 y 3 es 4, 5 y 26; las dos primeras no son referencia porque el equipo aprendía el framework.

---

## Comandos

```bash
# Cliente
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # obligatorio, genera database.g.dart
flutter analyze                                            # debe salir sin advertencias
flutter test                                               # 56 pruebas, todas en verde
flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

# Backend (en Windows el intérprete es .venv/Scripts/python.exe)
npx --yes firebase-tools emulators:start --only firestore --project demo-aprueba   # emulador, desde la raíz
cd backend
uv venv --python 3.12 .venv
uv pip install --python .venv -r requirements-dev.txt
.venv/bin/python -m app.seed     # datos de prueba; pide SEED_DEMO_UID y SEED_DEMO_NEW_UID en .env
.venv/bin/python -m app          # API en /api/v1
.venv/bin/python -m pytest       # 68 pruebas; sin emulador, 42 y 26 omitidas

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
- [ ] La búsqueda de secretos solo coincide con los cuatro archivos versionados esperados de la regla 2; se revisó cualquier coincidencia adicional, incluidas cachés ignoradas
- [ ] Ningún texto del banco real está en los archivos versionados (regla 8)

**Integridad del dominio**
- [ ] La respuesta correcta y la explicación siguen protegidas en los cinco puntos (RNF-02)
- [ ] La pendiente impide recorrer el banco sin cuota, incluso con peticiones simultáneas (RNF-04, T-25)
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
- [ ] Vocabulario XP e IDs del Product Backlog vigente; las equivalencias académicas con Scrum se conservan
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
    local/     Drift: caché y preferencias
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
  diccionario_de_datos.md   entregable EDT 1.3.7.1, documento del modelo de datos
seed/README.md              lo que carga el seed, con ejemplos
```

**Flujo de datos:** UI → provider → repositorio → `ApiClient` (Dio). La interfaz nunca habla directo con la red. El perfil recupera su última copia de Drift ante una falla de red. La práctica guarda las preguntas descargadas, pero `next()` y `question()` todavía requieren la API y no recuperan esa copia al fallar. HU-14, en la iteración 9, debe completar la práctica sin conexión (RNF-08).

**Sesión:** Firebase Auth con correo y contraseña. La app envía en `Authorization` el ID token de Firebase, que dura una hora y que el SDK de Firebase renueva solo. El backend lo valida con `verify_id_token` de `firebase-admin` en `backend/app/core/deps.py`, y no emite ni renueva tokens. Ante un 401, `ApiClient` pide un token nuevo con `getIdToken(forceRefresh: true)` y reintenta una sola vez. Si el reintento vuelve a dar 401, o Firebase ya no tiene usuario, llama a `AuthController.logout()`, que cierra la sesión de Firebase y borra la caché de Drift. Después el router redirige al inicio. Decidido en ADR-40.

---

## Reglas de negocio

1. Cuota gratuita base 10, más 5 por colegio y 5 por región, con tope 20. `plans.free.limits.qDay=20` representa el tope, y `qDay=0` es ilimitado (ADR-76). Cada bonificación se reclama una sola vez. Reinicio diario y descuento al responder. La base y los bonos son constantes de `backend/app/core/config.py`. Producción conserva `qDay` 10 en `plans/free` hasta la próxima carga del seed desde `main` revisada.
2. Ni la respuesta correcta ni la explicación viajan antes de responder (RNF-02). La pregunta entregada queda pendiente y se repite hasta responderla, incluso si cambian las preferencias. La pendiente se fija con una escritura condicionada, así las peticiones simultáneas reciben la misma (RNF-04, ADR-81 y ADR-84).
3. Medallas de bronce: las de cada respuesta correcta salen de `plans/{plan}.badges.correct`. Cada desbloqueo de cuota da 1, fijado en `UNLOCK_MEDALS`. Una recorrección confirmada da 250, y los otorga la administración al aprobar, no el estudiante al enviar. La medalla por ingreso diario (`badges.login`) es de un módulo fuera del alcance (ADR-68). Cada movimiento va a `medalTransactions` y suma en `users.medalWallet` y `badgesTotal` en la misma transacción (ADR-59).
4. `cohortPercentile` compara el tiempo de respuesta contra la cohorte de esa pregunta. HT-04 / T-30 lo calcula desde `questions.stats.elapsedBuckets`, sin agregaciones (RNF-12, ADR-63). T-28 mide desde `deliveredAt`, la hora en que la API entregó la pendiente (ADR-84); el cronómetro del cliente no es la fuente. El cálculo al responder y el histograma llegan con HU-03 y HT-04.
5. El facsímil requiere que el plan incluya `mock_mode` y presenta orden fijo por prueba, como un ensayo (ADR-77 y ADR-79). `random` es el modo libre. El código todavía selecciona al azar en ambos formatos y tiene un fallback por pago si falta la funcionalidad; HU-12 debe corregirlo. Las recorrecciones no dependen del plan.
6. Las materias que no son PAES llegan con `hasQuestions: false`.
7. Dificultad de `d1` a `d4`, estricta para preguntas nuevas. Si se agota en las pruebas elegidas, se avisa sin cambiarla automáticamente (ADR-78). Las preguntas admiten cuatro o cinco alternativas, y la letra enviada debe existir en esa pregunta (ADR-80).
8. Los errores de negocio se traducen a estados de interfaz. Alcanzar la cuota base lleva a la pantalla de desbloqueo, no a un error.

**Errores propios del módulo:** `QUOTA_BASE_REACHED` 422, `QUOTA_DAILY_LIMIT` 422, `NO_QUESTIONS_AVAILABLE` 404, `ALREADY_ANSWERED` 409, `INVALID_OPTION` 400, `BONUS_ALREADY_CLAIMED` 409, `QUOTA_MAX_REACHED` 422, `CORRECTION_ALREADY_OPEN` 409, `FORMAT_REQUIRES_PLAN` 422, `NO_TESTS_SELECTED` 400.

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
- **ADR-12** Sanitización centralizada de `correctAnswer` y `explanation` en la capa de servicios (RNF-02)
- **ADR-30** Backend en Python 3.12 con FastAPI, por decisión de la contraparte. Sus convenciones vienen del backend de administración de Max (ADR-31)
- **ADR-40** Autenticación con Firebase Auth, por decisión de la contraparte. El backend verifica el ID token con `firebase-admin` y no tiene JWT propio ni refresh token. Reemplaza ADR-20 y ADR-38
- **ADR-43** `verify_id_token` sin revisar revocación. El retraso de hasta una hora en rechazar un token revocado queda cubierto por el rechazo de usuarios suspendidos y la comprobación de `sessionsRevokedAt` que hace `get_current_student` (ADR-65 y ADR-71)
- **ADR-49**, en la parte del proyecto local, con el ajuste del 2026-09-25: en local Firestore usa el emulador con el proyecto `demo-aprueba` (`FIRESTORE_EMULATOR_PROJECT_ID`), y `FIREBASE_PROJECT_ID` lleva el ID real, `aprueba-app-modulo-preguntas`, solo para validar tokens de Firebase Auth
- **ADR-56** Los 35 commits de "Audit Sim" en `main` no se reescriben. Los agentes commitean con la identidad global de quien los opera (regla 7)
- **ADR-57** El modelo sigue a la administración donde ella define una colección o un campo, y al modelo de datos de junio y su extensión del generador donde no. Decidido por la contraparte
- **ADR-58** El ID de `users` es `usr_` más el UID de Firebase, porque la consola valida ese prefijo
- **ADR-59** Las medallas se mueven en `medalTransactions`, con IDs `mtx_*`, en la misma transacción que actualiza `users.medalWallet` y `badgesTotal`. Reemplaza a `users/{uid}/medalLedger`
- **ADR-60** `answers` es subcolección de `users`: `users/usr_<UID>/answers`
- **ADR-61** `corrections` tiene la forma que lee la cola de la consola, con IDs `cor_*`
- **ADR-62** `questions` usa IDs `qst_*` y los campos del generador. Solo se sirven preguntas `published`, y `published` implica `approved`
- **ADR-63** Percentil de cohorte con el histograma de `questions.stats`, actualizado en la transacción de responder. Sustituye a ADR-10 y ADR-23
- **ADR-64** Reemplazada en la interpretación de cuota por ADR-76. Las medallas por acierto siguen saliendo de `badges.correct`, ratificadas por ADR-83. El seed carga `qDay` 20 en `free`; producción lo recibe con la próxima carga desde `main`
- **ADR-65**, en la parte que decidió el equipo: un token con `auth_time` anterior a `sessionsRevokedAt` da 401, en la misma lectura de `users` que hacen el alta y el control de suspendidos
- **ADR-66** El backend crea `users/usr_<UID>` en la primera petición autenticada, solo con los campos de la administración y los del módulo. `GET /me` entrega `quota.unlimited`. El seed crea las cuentas de demostración con la misma función, `new_user()`
- **ADR-67** `reason` guarda el comentario del alumno, o la etiqueta en español del código si no hay comentario. El código va en `reasonCode`
- **ADR-68 y ADR-82** Max ratificó que solo se actualiza `lastActivityAt`. Racha, medalla diaria y `activity` quedan fuera del módulo
- **ADR-70, ADR-77 y ADR-79** Facsímil requiere `mock_mode` y orden fijo por prueba. El fallback por pago de ADR-70 y el azar del facsímil de ADR-73 quedan reemplazados
- **ADR-71** `get_current_student` lee una vez `users/usr_<UID>` en cada petición del alumno. Lo crea si no existe, responde 401 si la sesión fue revocada y 403 si está suspendido, y marca `lastActivityAt` una vez al día. Los detalles de implementación son propuesta
- **ADR-72 y ADR-81** Max ratificó descuento al responder y pregunta pendiente. `progress` sale de la cuota del día y `hasQuestions` es `approvedStock > 0`. Con `selectedTests` vacío, `PUT /me/preferences` responde `NO_TESTS_SELECTED` 400; `GET /practice/next` sin pruebas sigue ADR-29. La pendiente se fija de forma atómica y guarda `deliveredAt` (ADR-84)
- **ADR-73**, en la parte ratificada: la pregunta pendiente se mantiene aunque cambien las preferencias, y `testId` y `sessionId` no se implementan mientras la app no los envíe
- **ADR-74** Cada error de negocio es un estado de la pantalla Pregunta, y "sin conexión" aparece solo cuando no hay respuesta del servidor. El cambio en `lib/core/` alcanza pantallas fuera del alcance, listadas en la ADR, y se informa a Max
- **ADR-75** El banco real nunca se versiona. La importación espera clasificación y curación de la empresa. La consulta sobre curarlo con IA es un cambio de alcance pendiente; la demo sigue con el seed sintético
- **ADR-78 y ADR-80** Max confirmó dificultad estricta con aviso y preguntas de cuatro o cinco alternativas
- **ADR-83** Max confirmó seguir la sección 2.8 para medallas y recorrecciones. Se avisó al equipo de la consola sobre `flagCount` y el registro de la medalla; no se da por corregido su código
- **ADR-84** La pendiente se fija con una escritura condicionada al `update_time` leído (T-25) y guarda `deliveredAt`, la hora de la API desde la que se mide el tiempo de respuesta (T-28)
- **ADR-85** `GET /questions/{id}` solo entrega la pendiente o una pregunta respondida; cualquier otra da `NOT_FOUND`, exista o no (RNF-04)

ADR-11 y ADR-12, los tramos de ADR-63, las decisiones menores de ADR-69 y los detalles de ADR-71 conservan sus pendientes de ratificación cuando no hay evidencia posterior. Las aprobaciones de Jeremías del 27/09 están en la bitácora. Las confirmaciones de Max registradas en ADR-76 a ADR-83 no ratifican otros detalles de diseño ni sustituyen la aceptación de Martin.

---

## Cómo escribir

La profesora guía observó que la documentación se leía como generada por inteligencia artificial. Aplica esto a todo texto que produzcas, incluidos mensajes de commit, descripciones de pull request y documentos.

Prosa directa, sin adornos. Prohibido: guiones largos, la construcción "no solo X sino Y", listas de exactamente tres elementos, y las palabras "robusto", "integral", "fundamental", "clave", "garantizar", "en el marco de", "cabe destacar", "es importante señalar", "por otro lado", "en definitiva".

Párrafos en vez de viñetas cuando el contenido lo permita. No cierres las secciones con una frase que resuma lo ya dicho. No uses negrita para enfatizar dentro de párrafos. Escribe algunas oraciones cortas.

En los documentos, usa datos concretos del proyecto (nombres de archivo, números, problemas reales) en vez de afirmaciones generales.

**Mensajes de commit:** en español, formato `tipo(ámbito): descripción en minúscula`. Sin punto final.

---

## Iteración, calendario y pendientes al 01/10/2026

La iteración 4 corresponde a la semana 8, del 28/09 al 03/10/2026. Product Backlog v2.3 asigna HU-03, HU-04, HT-04, HU-12 y HT-06, con 15 puntos. El Plan de iteración v1.3 propone adelantar HT-03 y llegar a 18; el documento lo presenta como propuesta para el juego de planificación, no como acuerdo ya confirmado. Tareas: T-23, T-25 a T-35 y T-01. La Entrega 2 termina en la iteración 6, el 17/10.

| Semana y fechas | Hito |
|---|---|
| 8, 28/09 al 03/10 | Alloxentric: Hito 1, MVP con base de datos operativa |
| 9, 05 al 10/10 | Informe de avance |
| 10, 12 al 17/10 | Presentación de avance y video de 5 minutos |
| 11, 19 al 24/10 | Retroalimentación |
| 12, 26 al 31/10 | Alloxentric: Hito 2, proyecto en contenedores |
| 13, 02 al 07/11 | Presentación y definición de continuidad |
| 15, 16 al 21/11 | Informe final |
| 15 y 16, 16 al 28/11 | Alloxentric: Hito 3, entregado y documentado |
| 16, 23 al 28/11 | Correcciones posteriores al informe final |
| 17, 30/11 al 05/12 | Comisión evaluadora |
| 18, 07 al 12/12 | Empresas vinculadas |

La Entrega 1 fue aceptada por Martin el 29/09/2026: T-24, ocho de ocho pasos y hallazgos H-01 a H-07. El registro acredita la recarga del seed sintético tras integrar #25 a #28.

En el código existen seis servicios del módulo: `GET /me`, `GET /tests`, `GET` y `PUT /me/preferences`, `GET /practice/next` y `GET /questions/{id}` (T-20, ADR-85). `/health` es una sonda y no suma a los catorce. Faltan respuesta, explicación, habilidad, los dos servicios de cuota, los dos de recorrección y progreso. La implementación de cada historia necesita su aceptación; que la pantalla o el modelo exista no basta.

Pendientes de implementación: cálculo del tiempo desde `deliveredAt` al responder (T-28); histograma y percentil (T-30); orden de facsímil (T-32); permiso sin fallback por pago; validación de la letra elegida contra las alternativas de cada pregunta (T-29) y cobertura de cinco alternativas, que hoy bloquea `test_forma_de_las_preguntas_del_banco` al exigir cuatro en el seed; ruta web al recargar (T-26); representación de cita (T-27) y práctica sin conexión (HU-14). No los corrijas desde un encargo limitado a documentación.

Siguen pendientes la clasificación y curación del banco real, decidir cuál copia vale, la propuesta de curarlo con IA y la autorización del repositorio público. No se escriben importadores ni se infieren metadatos. Antes de la demo, una persona del equipo revisa las 10 preguntas de lectora en d1 del seed, que no se pueden recalcular con un script (ADR-73). El aviso de diferencias de `flagCount` y medalla ya se hizo al equipo de la consola, pero no hay evidencia de corrección de ese código. Las decisiones de Max sobre cuota, formato, dificultad, alternativas, pendiente y actividad ya están confirmadas; no vuelvas a presentarlas como consultas abiertas.

Las ratificaciones de propuestas del equipo que no tengan evidencia posterior siguen pendientes. No supongas que una sesión prevista para el 28/09 ocurrió ni que ratificó todas las ADR.
