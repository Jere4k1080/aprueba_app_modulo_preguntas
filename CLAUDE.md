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
- `sanitizeQuestion()` en `backend/src/services/questionService.js` elimina `correctAnswer` antes de emitir
- `GET /practice/next` y `GET /questions/{id}` no la incluyen
- `Question.correctAnswer` es nullable en el modelo Dart
- `CachedQuestions.correctAnswer` entra en nulo y solo se puebla tras responder, verificado en `test/drift_integrity_test.dart`
- `firestore.rules` niega al cliente toda lectura y escritura, así que nadie puede leer `questions` directo desde Firestore y saltarse `sanitizeQuestion()`. Decidido en ADR-21

Si un cambio toca cualquiera de esos puntos, verifica que la regla siga en pie.

**2. Ningún secreto se versiona.**
Antes de cualquier commit:

```bash
grep -rIl -E "serviceAccount|private_key|BEGIN PRIVATE KEY|sk_live|pk_live|AIza" . \
  --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=flutter --exclude-dir=build
```

Las credenciales van por `--dart-define` en el cliente y por variables de entorno en el backend. `.env.example` no lleva valores reales.

**3. Nada va directo a `main`.**
Una rama por tarea con nombre `feature/<descripción>`, un pull request por rama, y revisión de otro integrante antes de fusionar. Si te piden commitear a `main`, adviértelo antes de hacerlo.

**4. No subas versiones de dependencias para que algo compile.**
Ni en `pubspec.yaml` ni en `backend/package.json`. Si hay un conflicto de versiones, repórtalo y detente.

**5. Toda decisión tomada sin información suficiente va a `docs/bitacora_decisiones.md`**, con la alternativa descartada y el motivo. La bitácora es la mitigación declarada de la práctica XP de cliente en sitio, que el equipo no puede cumplir. No es opcional.

**6. No crees modelos de Firestore en el cliente Flutter.**
Decidido en ADR-03. La app habla con la API, no con la base de datos. Los esquemas de las colecciones viven en `seed/README.md` y en `docs/diccionario_de_datos.md`.

---

## Límites de alcance

Dentro del alcance: `lib/features/practice/` y los servicios del backend que lo alimentan. Seis pantallas y trece servicios.

**Fuera del alcance, aunque esté en el repositorio:** onboarding, registro y autenticación, home, medallas y canjes, grupos, comunidad, tutores, muro de pago, ajustes y notificaciones. Ese código es del cliente y no se toca.

Excepción: si `flutter analyze` reporta una advertencia en código fuera del módulo, se corrige, porque el analizador limpio es criterio de terminado. Hazlo en un commit separado para que el límite del alcance quede visible en el historial.

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

# Backend
cd backend
npm install
npm run emulator     # emulador de Firestore
npm run seed         # datos de prueba
npm start            # API en /api/v1
node test/health.test.js

# Verificadores sin SDK
python3 tool/check_static.py .
python3 tool/check_models.py
```

`build_runner` es obligatorio: `database.g.dart` no está versionado y sin él el proyecto no compila.

---

## Checklist de auditoría

Cuando revises trabajo hecho por otro agente, recorre esta lista y reporta el resultado de cada punto.

**Verificaciones automáticas**
- [ ] `flutter analyze` sin advertencias
- [ ] `flutter test` en verde, y el número de pruebas no bajó
- [ ] `node backend/test/health.test.js` en verde
- [ ] `build_runner` regenera sin conflictos
- [ ] La búsqueda de secretos no arroja resultados

**Integridad del dominio**
- [ ] La respuesta correcta sigue protegida en los cinco puntos
- [ ] Las reglas de Firestore coinciden con lo que dice `docs/diccionario_de_datos.md`
- [ ] Los índices de `firestore.indexes.json` respaldan consultas reales del módulo, no hipotéticas
- [ ] Las respuestas del backend respetan el envelope `{data, error, meta}` y el catálogo de errores
- [ ] Los errores de negocio se traducen a estados de interfaz, no a mensajes genéricos

**Proceso**
- [ ] El trabajo está en una rama, no en `main`
- [ ] Hay un pull request abierto
- [ ] Las decisiones nuevas quedaron en la bitácora
- [ ] El alcance respetado: no se tocó código del cliente fuera del módulo sin motivo

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

backend/
  src/
    routes/       endpoints bajo /api/v1
    services/     lógica de negocio, incluye sanitizeQuestion()
    middleware/   envelope, auth JWT, manejo de errores
    seed/         carga de datos de prueba

docs/
  bitacora_decisiones.md    ADR del proyecto
  diccionario_de_datos.md   entregable EDT 1.3.2.1
seed/README.md              esquemas de las colecciones
```

**Flujo de datos:** UI → provider → repositorio → `ApiClient` (Dio). La interfaz nunca habla directo con la red. Cada lectura se escribe en Drift y, ante error de red, el repositorio sirve la última copia.

**Sesión:** access token de 15 minutos en `Authorization`. Ante un 401 el interceptor renueva con el refresh token, que rota en cada uso, y reintenta. Si falla, cierra sesión y el router redirige al inicio.

---

## Reglas de negocio

1. Cuota diaria de 10 preguntas. Declarar colegio suma 5, declarar región suma 5, tope de 20. Los planes de pago la dejan ilimitada. Cada bonificación se reclama una sola vez. Reinicio diario.
2. La respuesta correcta no viaja al cliente antes de que el estudiante responda.
3. Medallas: 1 bronce por respuesta correcta, 1 por desbloqueo de cuota, 1 por ingreso diario, 250 por recorrección confirmada. Los 250 los otorga administración al aprobar, no el estudiante al enviar.
4. `cohortPercentile` compara la velocidad del estudiante contra su cohorte y llega precalculado desde el backend. Firestore no hace agregaciones económicas en consulta.
5. El modo facsímil requiere plan de pago; `random` es el modo libre.
6. Las materias que no son PAES llegan con `hasQuestions: false`.
7. Dificultad de `d1` a `d4`. El estudiante solo recibe preguntas de las pruebas que seleccionó.
8. Los errores de negocio se traducen a estados de interfaz. Alcanzar la cuota base lleva a la pantalla de desbloqueo, no a un error.

**Errores propios del módulo:** `QUOTA_BASE_REACHED` 422, `QUOTA_DAILY_LIMIT` 422, `NO_QUESTIONS_AVAILABLE` 404, `ALREADY_ANSWERED` 409, `INVALID_OPTION` 400, `BONUS_ALREADY_CLAIMED` 409, `QUOTA_MAX_REACHED` 422, `CORRECTION_ALREADY_OPEN` 409, `FORMAT_REQUIRES_PLAN` 422.

---

## Decisiones ya tomadas

Están en `docs/bitacora_decisiones.md`. No las vuelvas a discutir salvo que encuentres evidencia nueva; si la encuentras, dilo antes de cambiar nada.

- **ADR-01** `answers` y `corrections` son colecciones raíz con `userId`; `medalLedger` es subcolección de `users/{uid}`
- **ADR-02** `answers` y `corrections` son inmutables para el cliente: solo create, sin update ni delete
- **ADR-03** Sin modelos de Firestore en el cliente Flutter
- **ADR-04** `Question.correctAnswer` es nullable
- **ADR-05** `potentialReward` exige la estructura `{amount}`; nada de parseo tolerante que oculte defectos del backend
- **ADR-08** Se resuelven las advertencias del analizador; los avisos de deprecación heredados no se tocan
- **ADR-09** Exclusión de preguntas respondidas mediante `users/{uid}/state/practice` con `answeredQuestionIds`
- **ADR-10** Percentil de cohorte con umbrales precalculados en el documento de la pregunta
- **ADR-11** Reinicio de cuota configurable por variables de entorno
- **ADR-12** Sanitización centralizada de `correctAnswer` en la capa de servicios

Las ADR-09 a ADR-12 son propuestas pendientes de ratificación por el equipo.

---

## Cómo escribir

La profesora guía observó que la documentación se leía como generada por inteligencia artificial. Aplica esto a todo texto que produzcas, incluidos mensajes de commit, descripciones de pull request y documentos.

Prosa directa, sin adornos. Prohibido: guiones largos, la construcción "no solo X sino Y", listas de exactamente tres elementos, y las palabras "robusto", "integral", "fundamental", "clave", "garantizar", "en el marco de", "cabe destacar", "es importante señalar", "por otro lado", "en definitiva".

Párrafos en vez de viñetas cuando el contenido lo permita. No cierres las secciones con una frase que resuma lo ya dicho. No uses negrita para enfatizar dentro de párrafos. Escribe algunas oraciones cortas.

En los documentos, usa datos concretos del proyecto —nombres de archivo, números, problemas reales— en vez de afirmaciones generales.

**Mensajes de commit:** en español, formato `tipo(ámbito): descripción en minúscula`. Sin punto final.

---

## Pendientes conocidos

Verifica si siguen abiertos antes de reportarlos. Estado revisado el 2026-09-23:

- ADR-09 a ADR-12 pendientes de ratificación
- El repositorio es público y contiene el código completo del cliente. Pendiente de confirmación con la contraparte
- Los trece servicios del módulo no están implementados. La API está desplegada en `https://aprueba-app-modulo-preguntas-api.vercel.app/api/v1`, pero solo responde `/health`
Ya no son pendientes: la app web responde 200 en `https://aprueba-app-modulo-preguntas.vercel.app`, y `firestore.rules` niega al cliente toda lectura y escritura en el proyecto `aprueba-app-modulo-preguntas`, con las reglas activas iguales al archivo. El seed de demostración está cargado en ese proyecto desde el 2026-09-23, con IDs fijos, y un cliente anónimo recibe 403 al leer cualquiera de sus documentos. El PR #12 está fusionado en main y backend/vercel.json ya está versionado. El 2026-09-23, la API respondió 200 en /health y el preflight de la vista previa respondió 204 con Access-Control-Allow-Origin. Que las vistas previas y las URLs propias de cada despliegue pidan iniciar sesión en Vercel es la protección del proyecto, no un error.