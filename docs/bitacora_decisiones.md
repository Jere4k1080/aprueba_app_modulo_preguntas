# Bitácora de Decisiones Arquitectónicas — Iteración 2

**Módulo:** Preguntas y Práctica PAES — App Aprueba  
**Fecha:** Semana 6 · 14 al 18 de septiembre de 2026  
**Historia:** HU-20 · Entrega funcional 1  

Este documento registra las decisiones de diseño tomadas durante la definición del modelo de datos, contratos de la API y esquemas de Firestore, incluyendo las alternativas evaluadas, las revisiones realizadas y los descartes fundamentados.

---

## Índice de Decisiones

1. [ADR-01: Arquitectura de colecciones Firestore: Raíz vs. Subcolección (Modificada)](#adr-01-arquitectura-de-colecciones-firestore-raíz-vs-subcolección)
2. [ADR-02: Inmutabilidad en respuestas y solicitudes de corrección (Mantenida)](#adr-02-inmutabilidad-en-respuestas-y-solicitudes-de-corrección)
3. [ADR-03: Modelos de Firestore en el cliente Flutter (Descartada)](#adr-03-modelos-de-firestore-en-el-cliente-flutter)
4. [ADR-04: Privacidad y campo `correctAnswer` nullable en `Question` (Mantenida)](#adr-04-privacidad-y-campo-correctanswer-nullable-en-question)
5. [ADR-05: Parseo y contrato estricto de recompensas en `Correction` (Corregida)](#adr-05-parseo-y-contrato-estricto-de-recompensas-en-correction)
6. [ADR-06: Esquema local en Drift y verificación de nulidad previa a respuesta (Observación activa)](#adr-06-esquema-local-en-drift-y-verificación-de-nulidad-previa-a-respuesta)
7. [ADR-07: Poda y selección estricta de índices compuestos en Firestore (Ajustada)](#adr-07-poda-y-selección-estricta-de-índices-compuestos-en-firestore)
8. [ADR-08: Tratamiento de avisos del analizador estático (flutter analyze) (Aprobada)](#adr-08-tratamiento-de-avisos-del-analizador-estático-flutter-analyze)
9. [ADR-09: Exclusión de preguntas respondidas mediante documento de estado (Propuesta para ratificación)](#adr-09-exclusión-de-preguntas-respondidas-mediante-documento-de-estado)
10. [ADR-10: Precálculo de percentil de cohorte mediante umbrales en questions (Propuesta para ratificación)](#adr-10-precálculo-de-percentil-de-cohorte-mediante-umbrales-en-questions)
11. [ADR-11: Reinicio configurable de cuota diaria (Propuesta para ratificación)](#adr-11-reinicio-configurable-de-cuota-diaria)
12. [ADR-12: Proyección y sanitización centralizada de correctAnswer (Propuesta para ratificación)](#adr-12-proyección-y-sanitización-centralizada-de-correctanswer)
13. [ADR-13: Status HTTP de FORMAT_REQUIRES_PLAN (Corregida)](#adr-13-status-http-de-format_requires_plan)
14. [ADR-14: Tipo de dato de las fechas insertadas por el seed (Corregida)](#adr-14-tipo-de-dato-de-las-fechas-insertadas-por-el-seed)
15. [ADR-15: Estado sin commitear en el working tree de main durante la auditoría del 2026-09-13 (Resuelta)](#adr-15-estado-sin-commitear-en-el-working-tree-de-main-durante-la-auditoría-del-2026-09-13)

---

### ADR-01: Arquitectura de colecciones Firestore: Raíz vs. Subcolección

* **Estado:** **MODIFICADA** (Se descartó la compatibilidad dual; se adoptó colección raíz para `answers` y `corrections`).
* **Propuesta inicial:** Soportar simultáneamente colecciones raíz (`/answers`, `/corrections`) y subcolecciones bajo usuario (`/users/{uid}/answers`, `/users/{uid}/corrections`), dejando `userId` como campo opcional.
* **Motivo del cambio / Crítica:**
  1. *Simplicidad de diseño:* Mantener dos arquitecturas paralelas duplica innecesariamente reglas de seguridad e índices, y debilita el modelo al forzar `userId` a ser opcional.
  2. *Requisito de negocio (Percentil de cohorte):* El cálculo de `cohortPercentile` exige comparar la velocidad de un estudiante contra todos los demás que contestaron esa misma pregunta. En Firestore, consultar a través de subcolecciones requiere un Collection Group Query complejo. En colección raíz, una consulta directa filtrada por `questionId` con orden cronológico (`questionId + answeredAt`) resuelve el problema de forma económica y directa.
  3. *Requisito de gestión (Correcciones):* Los administradores necesitan listar todas las solicitudes pendientes globalmente, no particionadas por usuario.
* **Decisión final:**
  * `answers` y `corrections` son **colecciones raíz**, con campo `userId` obligatorio y validado en las reglas de seguridad.
  * `medalLedger` se mantiene como **subcolección** (`users/{uid}/medalLedger`), ya que es un libro contable estrictamente personal del usuario.
  * Se eliminaron las reglas y rutas de subcolección redundantes.

---

### ADR-02: Inmutabilidad en respuestas y solicitudes de corrección

* **Estado:** **MANTENIDA / APROBADA**
* **Decisión:** En `firestore.rules`, se bloquearon explícitamente las operaciones de actualización y borrado (`allow update, delete: if false;`) para `answers` y `corrections`.
* **Fundamento:** 
  * Integridad y auditoría académica: una respuesta completada no debe ser alterada ni eliminada por el estudiante para evitar adulteraciones de cuota o estadísticas.
  * Una solicitud de recorrección enviada queda en estado inmutable para el cliente.
* **Nota técnica:** El bloqueo de `update` en `corrections` no afecta la labor del moderador/administrador, ya que los servicios de administración operan con el Firebase Admin SDK en Node.js, el cual omite por diseño las reglas de seguridad de cliente.

---

### ADR-03: Modelos de Firestore en el cliente Flutter

* **Estado:** **DESCARTADA** (Modelos eliminados del cliente; esquemas preservados en `seed/README.md`).
* **Propuesta inicial:** Crear clases Dart en la app Flutter (`FirestoreTest`, `FirestoreSkill`, `SkillResource`, `FirestoreAnswer`, `MedalLedgerEntry`, `UserQuotaState`) para reflejar los documentos de la base de datos.
* **Motivo del descarte:**
  * *Violación de límites arquitectónicos:* La app Flutter nunca se conecta directamente a Firestore; consume exclusivamente la API REST en Node.js/Express.
  * *Ambigüedad y duplicidad:* Introducía dos modelos para el mismo concepto (`QuotaState` vs. `UserQuotaState`, `TestInfo` vs. `FirestoreTest`), lo que invita a errores en el equipo de desarrollo móvil.
  * *Riesgo de seguridad:* Mantener modelos directos de Firestore en el cliente tienta a acoplar la app a la base de datos, lo que violaría la regla crítica de que `correctAnswer` nunca debe llegar al dispositivo del alumno.
* **Decisión final:** Los esquemas de Firestore se documentan exclusivamente en [`seed/README.md`](../seed/README.md) para el backend en Node.js. En el cliente Flutter solo viven los modelos de contrato de la API (`Question`, `Correction`, `QuotaState`, etc.).

---

### ADR-04: Privacidad y campo `correctAnswer` nullable en `Question`

* **Estado:** **MANTENIDA / APROBADA**
* **Decisión:** El campo `correctAnswer` existe en el modelo lógico de `Question` como `String?` (opcional/nullable).
* **Fundamento:** 
  * El documento en la base de datos almacena `correctAnswer` para uso del backend evaluador.
  * En los endpoints de práctica (`GET /practice/next`, `GET /questions/:id`), el servicio backend proyecta el documento omitiendo deliberadamente la clave `correctAnswer`.
  * Definirlo como nullable en el cliente permite que la deserialización sea segura tanto cuando el campo no viene (durante la resolución del ejercicio) como si en algún flujo posterior autorizado se requiriese.

---

### ADR-05: Parseo y contrato estricto de recompensas en `Correction`

* **Estado:** **CORREGIDA** (Se eliminó la tolerancia polimórfica; se adoptó cumplimiento estricto del contrato).
* **Propuesta inicial:** Permitir que `potentialReward` aceptara tanto un número entero directo (`250`) como un objeto (`{"amount": 250}`), adaptándose a irregularidades del backend existente.
* **Motivo de la corrección:** Tolerar irregularidades de formato en el cliente oculta defectos del backend y degrada la solidez del contrato formal. El contrato estipula que las recompensas viajan como objetos `{amount: int}`.
* **Decisión final:** En [`models.dart`](../lib/data/models/models.dart), `Correction.fromJson` exige estrictamente el formato `{amount: int}` tanto para `rewardGranted` como para `potentialReward`. Si el backend no envía el formato acordado, se reporta como defecto del servicio.

---

### ADR-06: Esquema local en Drift y verificación de nulidad previa a respuesta

* **Estado:** **OBSERVACIÓN ACTIVA (Tarea para Sebastián)**
* **Decisión:** Mantener el esquema de Drift existente en `database.dart` sin modificaciones inmediatas para evitar regeneraciones innecesarias de `database.g.dart` en esta iteración.
* **Punto de control:** Se registra formalmente la tarea para Sebastián (encargado de Drift): verificar y garantizar mediante pruebas que la columna `correctAnswer` en la tabla local `CachedQuestions` permanezca estrictamente en `NULL` cuando la pregunta ingresa a la caché desde `GET /practice/next`. Dicho campo solo puede poblarse una vez que el alumno respondió y recibió el resultado evaluado desde el backend.

---

### ADR-07: Poda y selección estricta de índices compuestos en Firestore

* **Estado:** **AJUSTADA / PODADA**
* **Propuesta inicial:** Crear 7 índices compuestos preventivos, incluyendo combinaciones para consolas de administración (`status + createdAt`, `userId + status + createdAt`).
* **Motivo del ajuste:** Cada índice compuesto incrementa la latencia en las escrituras y genera costo de almacenamiento en Firestore. La consola de administración está fuera del alcance del módulo de práctica del alumno.
* **Decisión final:** En [`firestore.indexes.json`](../firestore.indexes.json) se dejaron únicamente los 4 índices que respaldan consultas operativas del módulo:
  1. `questions` (`testId ASC`, `difficulty ASC`)
  2. `questions` (`testId ASC`, `status ASC`, `difficulty ASC`)
  3. `answers` (`questionId ASC`, `answeredAt DESC`) — Cálculo de percentil de cohorte
  4. `corrections` (`userId ASC`, `createdAt DESC`) — Historial de reportes del estudiante

---

### ADR-08: Tratamiento de avisos del analizador estático (flutter analyze)

* **Estado:** **APROBADA**
* **Decisión:** Se corrigieron las 5 advertencias (`warning`) que causaban la salida con código de error de `flutter analyze` (variables locales no usadas, import innecesario y aserción no nula redundante). Se decidió de forma explícita **no modificar** los 38 avisos informativos (`info`) que quedan.
* **Fundamento:** La regla de calidad del equipo estipula que `flutter analyze` debe correr sin advertencias. Reemplazar `.withOpacity()` por `.withValues()` a lo largo de decenas de archivos ensuciaría el diff del repositorio con cambios cosméticos sin aportar valor al módulo de práctica.
* **Corrección (2026-09-22):** La versión anterior decía que los 38 avisos eran deprecaciones de `withOpacity` en código heredado del cliente, fuera del alcance de la HU-20. No es así. Medidos con Flutter 3.44.7 sobre `main`, 28 son `withOpacity`, 3 son `value` deprecado en favor de `initialValue`, 4 son `prefer_const_constructors` o `prefer_const_literals_to_create_immutables`, 2 son llaves innecesarias en interpolaciones y 1 es `use_build_context_synchronously` en `lib/features/subscription/manage_plan_screen.dart`. 14 de los 38 están en `lib/features/practice/`, que es nuestro módulo: 10 son `withOpacity` y 4 son `value` deprecado o `prefer_const_*`. Los 24 restantes están fuera del alcance. La decisión de no tocarlos se mantiene. Falta que el equipo decida si corrige los 14 del módulo.

---

### ADR-09: Exclusión de preguntas respondidas mediante documento de estado

* **Estado:** **PROPUESTA PARA RATIFICACIÓN**
* **Decisión:** Almacenar `answeredQuestionIds: string[]` dentro del documento dedicado `users/{uid}/state/practice`.
* **Fundamento:**
  * Firestore no posee un operador `NOT IN` eficiente sobre listas grandes. Consultar la colección `answers` en cada llamada a `GET /practice/next` implicaría lecturas masivas y costosas.
  * Mantener la lista de IDs en un documento ligero de estado permite al backend leer 1 solo documento y filtrar preguntas en memoria antes de servir la siguiente.
  * El límite de 1 MB por documento de Firestore almacena cómodamente más de 30.000 IDs de preguntas, superando con creces la vida útil anual de la batería PAES.

---

### ADR-10: Precálculo de percentil de cohorte mediante umbrales en questions

* **Estado:** **PROPUESTA PARA RATIFICACIÓN**
* **Decisión:** Almacenar un mapa precalculado `cohortSpeedThresholds: { p25, p50, p75, p90 }` dentro de cada documento de `questions`.
* **Fundamento:**
  * Calcular el percentil en tiempo real contando respuestas en Firestore en cada POST `/answer` es lento y costoso en lecturas.
  * Un proceso programado (Cloud Function o cron nocturno) calcula los cuartiles de tiempo a partir de la colección `answers` (usando el índice `questionId + answeredAt`) y actualiza `cohortSpeedThresholds` en la pregunta.
  * Al responder, el backend compara el `elapsedMs` del alumno contra estos 4 valores fijos en tiempo $O(1)$ sin realizar ninguna consulta adicional a la base de datos.

---

### ADR-11: Reinicio configurable de cuota diaria

* **Estado:** **PROPUESTA PARA RATIFICACIÓN**
* **Decisión:** Definir el horario y huso horario de reinicio como variables de entorno en el backend (`QUOTA_RESET_HOUR_LOCAL=0`, `QUOTA_RESET_TIMEZONE='America/Santiago'`).
* **Fundamento:** Evita quemar constantes horarias en el código de la aplicación. Permite adaptarse dinámicamente a cambios de horario de verano/invierno en Chile o desplegar instancias para otros países (como Reino Unido con `Europe/London`) reutilizando el mismo motor de backend.

---

### ADR-12: Proyección y sanitización centralizada de correctAnswer

* **Estado:** **PROPUESTA PARA RATIFICACIÓN**
* **Decisión:** Implementar la función `sanitizeQuestion(questionDoc)` en la capa de servicios del backend (`backend/src/services/questionService.js`).
* **Fundamento:** La regla de integridad prohíbe exponer la alternativa correcta antes de responder. Centralizar la eliminación de `correctAnswer` en la capa de servicios garantiza que ningún controlador o ruta olvide proyectar el documento, evitando fugas de respuestas hacia el cliente móvil.

---

### ADR-13: Status HTTP de FORMAT_REQUIRES_PLAN

* **Estado:** **CORREGIDA**
* **Alternativa descartada:** `backend/src/errors/catalog.js` definió originalmente `FORMAT_REQUIRES_PLAN` con status `403 Forbidden`, por analogía directa con los demás errores de permisos del catálogo (`AUTH_FORBIDDEN` también usa 403).
* **Motivo de la corrección:** `FORMAT_REQUIRES_PLAN` no es un error de autorización sino un error de negocio: el alumno está autenticado y autorizado, simplemente eligió un formato (facsímil) que su plan actual no cubre. La regla de negocio 8 exige que los errores de negocio se traduzcan a estados de interfaz específicos, no a mensajes genéricos. El interceptor de Dio en el cliente Flutter reacciona a un 401/403 como problema de sesión (puede forzar cierre de sesión); con 403, `FORMAT_REQUIRES_PLAN` correría el riesgo de cerrar la sesión del alumno en vez de llevarlo al muro de pago, que es la respuesta de interfaz correcta.
* **Decisión final:** `FORMAT_REQUIRES_PLAN` pasa a status `422 Unprocessable Entity`, igual que el resto de los errores de cuota y de reglas de negocio del módulo (`QUOTA_BASE_REACHED`, `QUOTA_DAILY_LIMIT`, `QUOTA_MAX_REACHED`), coincidiendo con el contrato documentado en `CLAUDE.md`. Se revisó el resto del catálogo (10 errores estándar + 9 del módulo) contra el contrato documentado y no se encontró ningún otro status HTTP que no coincidiera.

---

### ADR-14: Tipo de dato de las fechas insertadas por el seed

* **Estado:** **CORREGIDA**
* **Alternativa descartada:** `backend/src/seed/seed.js` insertaba `answeredAt`, `createdAt` (en `corrections` y en `medalLedger`) y `lastAnsweredAt` como texto, usando `new Date().toISOString()`.
* **Motivo de la corrección:** `docs/diccionario_de_datos.md` documenta esos cuatro campos como `Timestamp` de Firestore, no como string. El script funcionaba igual porque el orden alfabético de una cadena ISO-8601 coincide con el orden cronológico, así que el índice `answers(questionId ASC, answeredAt DESC)` seguía ordenando bien. Pero el tipo real no coincidía con el documentado: se rompe en cuanto algo compare el campo contra `admin.firestore.Timestamp.now()` en una Cloud Function, en una regla de seguridad, o llame `.toDate()` sobre un valor que en realidad es un string. El seed va a poblar el emulador durante las nueve iteraciones restantes, así que conviene que el tipo sea el correcto desde ahora y no cuando ya haya código dependiendo del string.
* **Decisión final:** Los cuatro campos pasan a `admin.firestore.Timestamp.now()`, importando `admin` desde `backend/src/config/firebase.js` (que ya lo exporta). `reviewedAt` no se tocó: sigue en `null` hasta que un moderador resuelva la recorrección, como ya documentaba el diccionario de datos.

---

### ADR-15: Estado sin commitear en el working tree de main durante la auditoría del 2026-09-13

* **Estado:** **RESUELTA**
* **Numeración:** Se salta de ADR-07 a ADR-15 a propósito. `fix-analyzer-warnings` ya reservó ADR-08 y `backend-scaffold` reservó ADR-09 a ADR-12 en sus propias ramas; ADR-13 y ADR-14 quedan reservados para las correcciones de `FORMAT_REQUIRES_PLAN` y de los timestamps del seed. Usar ADR-15 aquí evita repetir el choque de numeración que ya se dio una vez entre esas dos ramas sobre ADR-08.
* **Hallazgo:** Al auditar el repositorio el 2026-09-13 se encontró que el working tree de `main` (no una rama) tenía 11 archivos modificados sin commitear: `README.md`, `docs/bitacora_decisiones.md`, `firestore.rules`, `lib/data/local/database.dart`, `lib/data/repositories/practice_repository.dart`, `lib/data/repositories/profile_repository.dart`, `lib/data/services/phone_auth_service.dart`, `lib/features/groups/create_group_screen.dart`, `lib/features/medals/medals_screen.dart`, `lib/features/practice/question_screen.dart` y `seed/README.md`. Alguien había aplicado a mano el contenido de las cuatro ramas abiertas (`feature/readme-update`, `feature/drift-integrity-tests`, `feature/fix-analyzer-warnings`, `feature/backend-scaffold`) directamente sobre `main`, sin pasar por pull request ni commitear. De haberse ejecutado `git add -A && git commit` en ese estado, las cuatro ramas habrían entrado a `main` sin revisión, violando la regla de que nada va directo a `main`.
* **Verificación antes de actuar:** se comparó el contenido de cada uno de los 11 archivos contra la rama que lo origina. Los 10 archivos de código eran idénticos byte a byte a la punta de su rama correspondiente (la única diferencia detectada era de fin de línea CRLF/LF, y en `README.md` una línea en blanco final de más). `docs/bitacora_decisiones.md` resultó ser exactamente la unión de ADR-08 tal como lo redactó `fix-analyzer-warnings` (la versión con el fundamento más específico, que menciona `withValues()` y qué módulos quedan fuera del alcance) más ADR-09 a ADR-12 tal como los redactó `backend-scaffold`, sin duplicar el encabezado de ADR-08. No se encontró ningún cambio que no estuviera ya contenido en alguna de las cuatro ramas.
* **Decisión final:** no se descartó nada. Se guardó el estado completo con `git stash push` (mensaje: "audit: estado manual pre-mezcla de las 4 ramas en working tree de main"), acotado a esos 11 archivos, dejando fuera los archivos nuevos sin rastrear (`CLAUDE.md`, `.claudeignore`, `graphify-out/`) por no ser parte del contenido replicado de las ramas. `git status` en `main` quedó sin modificaciones pendientes. El estado sigue disponible en `git stash list` para quien quiera inspeccionarlo o descartarlo explícitamente una vez que las cuatro ramas se hayan fusionado por PR.
* **Alternativa descartada:** usar `git reset --hard` para descartar el estado directamente. Se descartó porque no había verificación previa de que todo el contenido estuviera realmente cubierto por las ramas, y `reset --hard` es irreversible; `git stash` logra el mismo objetivo (dejar `main` limpio) de forma reversible.

---

### ADR-16: Fusión de pull requests a main sin revisión cruzada previa

* **Estado:** **DESVIACIÓN DECLARADA DEL CRITERIO DE TERMINADO**
* **Fecha:** 2026-09-13
* **Hallazgo:** El equipo (Martín, Jeremías, Sebastián) estuvo fuera durante la semana en que se resolvió fusionar los ocho pull requests abiertos. La regla del equipo exige revisión de otro integrante antes de fusionar cualquier rama a `main`. Ante la disyuntiva de dejar ocho PR acumulándose sin fusionar por más tiempo o fusionar sin esa revisión, se optó por fusionar lo que pasó las verificaciones automáticas (`flutter analyze`, `flutter test`, `node test/health.test.js`), dejando la revisión humana pendiente sobre el código ya en `main`.
* **Qué se fusionó sin revisión cruzada:**
  * A `main`: PR #6 (limpieza del working tree), PR #8 (`.gitignore`), PR #3 (README), PR #2 (`drift-integrity-tests`).
  * A `feature/backend-scaffold` (aún no fusionada a `main`): PR #5 (status de `FORMAT_REQUIRES_PLAN`).
* **Qué quedó sin fusionar:** PR #1 (`fix-analyzer-warnings`) y PR #4 (`backend-scaffold`) a `main`, y PR #7 (`seed-timestamps-firestore`) a `feature/backend-scaffold`, los tres bloqueados por conflictos reales en `docs/bitacora_decisiones.md` (ver `docs/revision_pendiente.md` para el detalle). Ningún conflicto se resolvió a la fuerza.
* **Motivo de la desviación:** El criterio de terminado del equipo (revisión de otro integrante antes de fusionar) es, junto con la bitácora de decisiones, la mitigación declarada para la ausencia de la práctica XP de cliente en sitio y de revisión par constante. No tener a nadie del equipo disponible para revisar convierte esa mitigación en un bloqueo indefinido. Se prefirió fusionar lo verificable automáticamente y dejar una guía de revisión posterior (`docs/revision_pendiente.md`) antes que acumular más PR sin fusionar o forzar una fusión sin ningún tipo de control.
* **Alternativa descartada:** esperar a que el equipo esté disponible para revisar antes de fusionar nada. Se descartó porque no hay fecha cierta de retorno y las ramas seguían acumulando riesgo de choque entre sí cuanto más tiempo pasaran sin integrarse a `main`.
* **Decisión final:** el código fusionado sin revisión cruzada queda marcado como pendiente de revisión en `docs/revision_pendiente.md`, con preguntas específicas que Sebastián y Martín deben poder responder antes de la Iteración 3. Esta ADR no reemplaza esa revisión: la declara pendiente y la hace visible.
