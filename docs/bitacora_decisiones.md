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
16. [ADR-16: Fusión de pull requests a main sin revisión cruzada previa (Desviación declarada)](#adr-16-fusión-de-pull-requests-a-main-sin-revisión-cruzada-previa)
17. [ADR-17: Proyecto de Vercel separado para el backend](#adr-17-proyecto-de-vercel-separado-para-el-backend)
18. [ADR-18: Cuenta de servicio de Firebase en base64](#adr-18-cuenta-de-servicio-de-firebase-en-base64)
19. [ADR-19: CORS por lista de orígenes y patrón](#adr-19-cors-por-lista-de-orígenes-y-patrón)
20. [ADR-20: JWT_SECRET obligatorio en producción](#adr-20-jwt_secret-obligatorio-en-producción)
21. [ADR-21: Firestore accesible solo desde la API](#adr-21-firestore-accesible-solo-desde-la-api)
22. [ADR-22: Confirmación para ejecutar el seed remoto](#adr-22-confirmación-para-ejecutar-el-seed-remoto)
23. [ADR-23: Recálculo diario del percentil con Vercel Cron](#adr-23-recálculo-diario-del-percentil-con-vercel-cron)
24. [ADR-24: Ubicación de Firestore para el proyecto de desarrollo](#adr-24-ubicación-de-firestore-para-el-proyecto-de-desarrollo)
25. [ADR-25: Ubicación de Firestore y región de la API aplicadas](#adr-25-ubicación-de-firestore-y-región-de-la-api-aplicadas)
26. [ADR-26: Preset Express y despliegues de Git solo desde main](#adr-26-preset-express-y-despliegues-de-git-solo-desde-main)
27. [ADR-27: Cuota y preferencias en `users/{uid}` según el modelo de la empresa](#adr-27-cuota-y-preferencias-en-usersuid-según-el-modelo-de-la-empresa)
28. [ADR-28: Supuesto sobre preferencias y cuota que el modelo de la empresa no define](#adr-28-supuesto-sobre-preferencias-y-cuota-que-el-modelo-de-la-empresa-no-define)
29. [ADR-29: Respuesta de `GET /practice/next` sin pruebas seleccionadas](#adr-29-respuesta-de-get-practicenext-sin-pruebas-seleccionadas)

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
* **Actualización de despliegue:** ADR-21 bloquea el acceso directo del cliente a Firestore. La API valida `userId` antes de escribir; las reglas ya no validan campos enviados por el estudiante.

---

### ADR-02: Inmutabilidad en respuestas y solicitudes de corrección

* **Estado:** **MANTENIDA / APROBADA**
* **Decisión:** En `firestore.rules`, se bloquearon explícitamente las operaciones de actualización y borrado (`allow update, delete: if false;`) para `answers` y `corrections`.
* **Fundamento:** 
  * Integridad y auditoría académica: una respuesta completada no debe ser alterada ni eliminada por el estudiante para evitar adulteraciones de cuota o estadísticas.
  * Una solicitud de recorrección enviada queda en estado inmutable para el cliente.
* **Nota técnica:** El bloqueo de `update` en `corrections` no afecta la labor del moderador/administrador, ya que los servicios de administración operan con el Firebase Admin SDK en Node.js, el cual omite por diseño las reglas de seguridad de cliente.
* **Actualización de despliegue:** ADR-21 también bloquea `create` desde el cliente. La inmutabilidad sigue vigente; las escrituras pasan por la API.

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
* **Estado al preparar Vercel:** el andamiaje actual todavía no ejecuta consultas compuestas. Los cuatro índices están preparados para los servicios de la Iteración 3; su uso debe verificarse cuando existan esas rutas.

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
* **Precisión (2026-09-23):** `Timestamp.now()` toma el reloj de la máquina que corre el seed. En la carga del 2026-09-23 ese reloj iba unos 13 s adelantado y `answeredAt` quedó 12,8 s después del `createTime` que asignó el servidor. El seed pasa a `admin.firestore.FieldValue.serverTimestamp()`, y Firestore escribe la hora de su servidor al confirmar cada escritura. El tipo sigue siendo `Timestamp`, así que la decisión anterior se mantiene.

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
  * A `feature/backend-scaffold`: PR #5 (status de `FORMAT_REQUIRES_PLAN`). Llegó a `main` el 2026-09-22 dentro del PR #4.
* **Qué quedó sin fusionar el 2026-09-13:** PR #1 (`fix-analyzer-warnings`) y PR #4 (`backend-scaffold`) a `main`, y PR #7 (`seed-timestamps-firestore`) a `feature/backend-scaffold`, los tres bloqueados por conflictos reales en `docs/bitacora_decisiones.md` (ver `docs/revision_pendiente.md` para el detalle). Ningún conflicto se resolvió a la fuerza.
* **Actualización (2026-09-22):** Sebastián y Martín aprobaron #7, #1 y #4 por WhatsApp. La aprobación no quedó registrada en GitHub; queda anotada aquí y en el cuerpo de cada commit de fusión. Con esa aprobación se fusionaron el 2026-09-22, en ese orden. En los tres el conflicto de la bitácora se resolvió conservando los bloques de ambas ramas sin cambios y en orden numérico. Después de cada fusión, `flutter analyze` y `flutter test` dieron lo mismo que una simulación previa. En `main` quedaron 0 advertencias y 38 avisos, con 29/29 pruebas en Flutter y 5/5 en el backend. Ese mismo día se fusionó el PR #10, con el índice completo y la corrección de ADR-08, sin revisión cruzada y por decisión explícita tomada durante la auditoría. Es la única fusión del 2026-09-22 que entra en esta desviación.
* **Motivo de la desviación:** El criterio de terminado del equipo (revisión de otro integrante antes de fusionar) es, junto con la bitácora de decisiones, la mitigación declarada para la ausencia de la práctica XP de cliente en sitio y de revisión par constante. No tener a nadie del equipo disponible para revisar convierte esa mitigación en un bloqueo indefinido. Se prefirió fusionar lo verificable automáticamente y dejar una guía de revisión posterior (`docs/revision_pendiente.md`) antes que acumular más PR sin fusionar o forzar una fusión sin ningún tipo de control.
* **Alternativa descartada:** esperar a que el equipo esté disponible para revisar antes de fusionar nada. Se descartó porque no hay fecha cierta de retorno y las ramas seguían acumulando riesgo de choque entre sí cuanto más tiempo pasaran sin integrarse a `main`.
* **Decisión final:** el código fusionado sin revisión cruzada queda marcado como pendiente de revisión en `docs/revision_pendiente.md`, con preguntas específicas que Sebastián y Martín deben poder responder antes de la Iteración 3. Esta ADR no reemplaza esa revisión: la declara pendiente y la hace visible.
* **Cierre del PR #9 (2026-09-22):** el usuario confirmó su aprobación por WhatsApp. La identidad del revisor no consta en GitHub; se dejó registro de esa limitación en un comentario del PR. Tras corregir tres afirmaciones de la guía y pasar la verificación de Vercel, el PR se fusionó a `main`.

---

### ADR-17: Proyecto de Vercel separado para el backend

* **Estado:** **APROBADA POR EL EQUIPO**
* **Decisión:** Desplegar la API en otro proyecto de Vercel con Root Directory `backend/`. `src/app.js` exporta Express y `src/server.js` escucha solo en desarrollo local, conforme a la [guía de Vercel para Express](https://vercel.com/docs/frameworks/backend/express).
* **Alternativa descartada:** servir la API bajo `/api` en el mismo proyecto que Flutter Web.
* **Motivo:** la raíz del repositorio tiene un build de Flutter y no contiene `package.json`; separar ambos proyectos evita mezclar comandos de compilación y variables de entorno. Como aún no existe el ID del proyecto Firebase, `.firebaserc` queda sin alias y el despliegue exige `--project`; se descartó inventar un ID provisional.
* **Actualización de despliegue:** con el ID real, `.firebaserc` fija `aprueba-app-modulo-preguntas` como proyecto predeterminado (ADR-25). La configuración de Vercel de la API está en `backend/vercel.json` (ADR-26).

---

### ADR-18: Cuenta de servicio de Firebase en base64

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** `FIRESTORE_EMULATOR_HOST` tiene prioridad. Fuera del emulador, `FIREBASE_SERVICE_ACCOUNT_BASE64` entrega el JSON a `admin.credential.cert()`. Sin ninguna de las dos variables, la API falla al iniciar. Se reutiliza la instancia de Firebase Admin cuando ya existe.
* **Alternativa descartada:** depender de un archivo JSON mediante `GOOGLE_APPLICATION_CREDENTIALS` o aceptar credenciales predeterminadas de forma implícita.
* **Motivo:** Vercel recibe secretos por variables de entorno. El base64 conserva los saltos de línea de la cuenta de servicio y el fallo explícito evita iniciar contra un proyecto distinto al previsto.

---

### ADR-19: CORS por lista de orígenes y patrón

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** `ALLOWED_ORIGINS` contiene orígenes exactos separados por comas. `ALLOWED_ORIGIN_PATTERN` admite una expresión regular opcional para vistas previas de Vercel. Las solicitudes `OPTIONS` reciben respuesta sin habilitar credenciales. Se reutiliza `cors` 2.8.6, que ya estaba en el lockfile, y se fija su versión exacta.
* **Alternativa descartada:** `cors()` sin restricciones y una lista fija de cada URL de vista previa.
* **Motivo:** el origen de producción es estable y las URLs de vista previa cambian en cada despliegue. `Authorization` viaja en una cabecera, sin cookies.

---

### ADR-20: JWT_SECRET obligatorio en producción

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** la carga de configuración falla cuando `NODE_ENV=production` y falta `JWT_SECRET`. El valor de desarrollo solo sirve fuera de producción.
* **Alternativa descartada:** conservar el secreto público de respaldo en producción.
* **Motivo:** ese valor está versionado como ejemplo y permitiría firmar tokens válidos si el operador omite la variable.

---

### ADR-21: Firestore accesible solo desde la API

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Hallazgo:** la regla anterior dejaba leer `questions` a cualquier usuario autenticado. Cada documento contiene `correctAnswer`; una lectura directa evitaba `sanitizeQuestion()`. También permitía crear respuestas con `correct` elegido por el cliente y modificar `users/{uid}/state/practice`.
* **Decisión:** `firestore.rules` bloquea todas las lecturas y escrituras de SDKs cliente. La app usa la API y Firebase Admin accede con IAM sin pasar por estas reglas, como indica la [documentación de Firebase](https://firebase.google.com/docs/firestore/security/rules-conditions).
* **Alternativa descartada:** conservar accesos directos con validaciones por colección. No se puede ocultar `correctAnswer` al entregar el documento completo de una pregunta y el cliente no necesita acceso directo según ADR-03.

---

### ADR-22: Confirmación para ejecutar el seed remoto

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** `npm run seed` opera con el emulador; fuera de él exige `SEED_ALLOW_REMOTE=true` antes de abrir Firestore.
* **Alternativa descartada:** permitir que la variable de credenciales por sí sola habilite el seed remoto.
* **Motivo:** el script usa IDs fijos con `.set()` y puede reemplazar documentos existentes y sus marcas de tiempo en el proyecto real.
* **Actualización (2026-09-23):** el seed ya carga datos en el proyecto real, así que sus preguntas y habilidades llevan `isDemo: true` y los documentos nuevos usan IDs con el segmento `demo`, como `q_demo_m1_d3` o `sk_demo_m1_operatoria`. Volver a correr el seed no pisa preguntas reales aunque la empresa use IDs como `q_m1_001`, y los datos de demostración se pueden filtrar o borrar con una consulta. Se descartaron los IDs correlativos sin marca, porque podían coincidir con los del banco real y el seed los habría sobrescrito. `q_lectora_001` y `sk_lectora_comp_lit` conservan su ID porque otros documentos del seed los referencian.

---

### ADR-23: Recálculo diario del percentil con Vercel Cron

* **Estado:** **PROPUESTA PARA RATIFICACIÓN, SIN IMPLEMENTAR**
* **Propuesta:** en la Iteración 4, un cron diario de Vercel llamaría a un endpoint interno de la API para actualizar los umbrales de `cohortSpeedThresholds` descritos en ADR-10.
* **Alternativa descartada por ahora:** Cloud Function programada.
* **Motivo:** el proyecto Firebase usa Spark; [Firebase exige Blaze para desplegar Cloud Functions](https://firebase.google.com/docs/functions/get-started). La propuesta no agrega todavía ni el cron ni el endpoint.

---

### ADR-24: Ubicación de Firestore para el proyecto de desarrollo

* **Estado:** **DECIDIDA POR EL EQUIPO, APLICADA EL 2026-09-23 (ver ADR-25)**
* **Decisión:** crear la base Firestore predeterminada del proyecto Firebase propio de desarrollo en la región `southamerica-east1` (São Paulo). Configurar las funciones del proyecto Vercel de la API en `gru1` (São Paulo). La app Flutter Web sigue en su proyecto Vercel separado.
* **Alternativa descartada:** `southamerica-west1` (Santiago). Firestore la ofrece, pero [Vercel no tiene una región de funciones en Santiago](https://vercel.com/docs/regions). Con la API en `gru1`, cada acceso a la base cruzaría entre São Paulo y Santiago. También se descarta dejar la región predeterminada `iad1` de Vercel.
* **Motivo:** según ADR-21, el cliente consulta Firestore solo por la API. Ubicar API y base en la misma ciudad evita ese tramo adicional en cada lectura y escritura. [Firestore permite ambas regiones sudamericanas](https://firebase.google.com/docs/firestore/locations) y [Vercel recomienda ejecutar las funciones cerca de la base](https://vercel.com/docs/functions/configuring-functions/region). La cuota gratuita de Firestore se aplica a [una base por proyecto](https://firebase.google.com/docs/firestore/pricing). La ubicación de una base ya creada no se puede cambiar; antes de provisionarla se debe comprobar que el proyecto nuevo no tenga una ubicación fijada por otro recurso.

---

### ADR-25: Ubicación de Firestore y región de la API aplicadas

* **Estado:** **APLICADA EL 2026-09-23**
* **Decisión:** ADR-24 quedó aplicada en el proyecto Firebase `aprueba-app-modulo-preguntas` (número 1073481331997), en plan Spark. La base `(default)` es Firestore nativo, edición Standard, en `southamerica-east1`, creada el 2026-09-23 a las 02:58 UTC y con la cuota gratuita asignada. La API corre en el proyecto de Vercel `aprueba-app-modulo-preguntas-api` con la región de funciones en `gru1`: `vercel inspect` del despliegue de producción muestra la función `index` en `gru1`. Con el ID ya creado, `.firebaserc` lo fija como proyecto predeterminado.
* **Alternativa descartada:** dejar `.firebaserc` sin proyecto y exigir `--project` en cada despliegue, como establecía ADR-17. Esa regla existía porque el ID todavía no estaba creado. No hubo que evaluar un cambio de región para la API: la base ya estaba en la ubicación de ADR-24, que no se puede cambiar después de creada.
* **Verificación:** el MCP de Firebase confirmó la ubicación de la base y la facturación deshabilitada. Las reglas activas coinciden con `firestore.rules`, y una lectura anónima por la API REST de Firestore sobre `questions`, `answers`, `corrections`, `tests`, `skills` y `users/{uid}/state/practice` devuelve 403 `PERMISSION_DENIED`. Los cuatro índices compuestos de `firestore.indexes.json` quedaron en estado `READY`. El proyecto también tiene una instancia de Realtime Database que el módulo no usa; sus reglas niegan lectura y escritura.

---

### ADR-26: Preset Express y despliegues de Git solo desde main

* **Estado:** **IMPLEMENTADA Y APROBADA EL 2026-09-23**
* **Hallazgo:** el proyecto de Vercel de la API se había creado con el preset Other, sin Express. El primer despliegue con la CLI falló por otra razón: sin un `vercel.json` en `backend/`, la CLI aplicó el de la raíz, que es de la app web, y ejecutó `bash vercel-build.sh` junto con el rewrite a `/index.html`.
* **Decisión:** `backend/vercel.json` declara `"framework": "express"` y limita los despliegues de Git con `git.deploymentEnabled`, usando `"**": false` y `"main": true`. Vercel despliega una rama si al menos una regla que la cubre vale `true`, así que solo `main` genera despliegues, y van a producción. El proyecto quedó conectado a `Jere4k1080/aprueba_app_modulo_preguntas` con `vercel git connect`. La CLI sigue pudiendo desplegar cualquier rama.
* **Alternativas descartadas:** cambiar el preset y el Ignored Build Step desde el panel de Vercel. Funcionaría, pero la configuración quedaría fuera del repositorio y sin revisión. También se descartó `ignoreCommand` en `vercel.json`, porque Vercel crea el despliegue y después lo cancela.
* **Consecuencias:** Vercel lee git.deploymentEnabled del commit que se empuja. El primer despliegue de producción salió del commit 80def89 de la rama feature/deploy-backend-vercel. En ese momento, el código de backend/ era idéntico al de main; solo difería backend/vercel.json. El PR #12 llevó esa configuración a main el 2026-09-23. Después de la fusión, /health respondió 200 y el preflight de la vista previa respondió 204 con Access-Control-Allow-Origin.

---

### ADR-27: Cuota y preferencias en `users/{uid}` según el modelo de la empresa

* **Estado:** **APROBADA POR EL EQUIPO (2026-09-23)**
* **Contexto:** el diccionario del módulo no definía el documento `users/{uid}`. El modelo de datos de la empresa (Aprueba, Modelo de Datos Firebase/Firestore v1.0) lo define como el perfil del alumno. Ahí la cuota es el mapa `quota` `{used, max, date, bonusSchool, bonusAddress, unlimited}`, y las preferencias `selectedTests`, `practiceFormat` y `difficulty` van en el primer nivel. La consola de administración, que construye otro equipo, lee ese documento.
* **Decisión:** los servicios del módulo leen y escriben la cuota y las preferencias en esos campos de `users/{uid}`. El documento lo crea el registro, fuera de nuestro alcance, así que un usuario nuevo puede llegar sin él. En ese caso los servicios usan cuota base de 10, sin bonos y 0 usadas, y ninguna prueba seleccionada (ADR-29). El seed crea los dos usuarios de demostración con todos los campos obligatorios del modelo.
* **Alternativa descartada:** guardar la cuota en `users/{uid}/state/quota`, con el mismo patrón que `state/practice` (ADR-09). Quedaba fuera del documento que lee la consola de administración.
* **Pendiente:** confirmar con la empresa qué hacer cuando hay que descontar cuota y el documento no existe. Escribir solo `quota` dejaría un documento sin los demás campos obligatorios del modelo.

---

### ADR-28: Supuesto sobre preferencias y cuota que el modelo de la empresa no define

* **Estado:** **SUPUESTO, PENDIENTE DE CONFIRMAR CON LA EMPRESA**
* **Supuesto:** el contrato de la API (`Preferences`) incluye `gradeId` y `onboarded`, que el modelo de la empresa no define. `gradeId` va como texto opcional en el primer nivel de `users/{uid}`, igual que `country`, `school` y `region`. `onboarded` no se guarda: se deriva de que `selectedTests` tenga al menos una prueba. También se supone que `quota.date` es un texto `YYYY-MM-DD` en el huso de reinicio de ADR-11, con el formato de `lastActiveDate`, y que `quota.max` es el límite del día con los bonos ya sumados.
* **Motivo:** el modelo de la empresa pone las preferencias en el primer nivel del documento, sin un mapa propio, y guarda los días como texto en `lastActiveDate`. Seguir esa estructura evita inventar campos que la consola no conoce.
* **Alternativa descartada:** un mapa `preferences` con todos los campos del contrato. Duplicaba `selectedTests`, `practiceFormat` y `difficulty`, que el modelo ya tiene en el primer nivel.
* **Impacto si es falso:** cambia dónde `PUT /me/preferences` guarda el grado, cómo se calcula `onboarded` y cómo se compara `quota.date` al reiniciar la cuota.

---

### ADR-29: Respuesta de `GET /practice/next` sin pruebas seleccionadas

* **Estado:** **DECIDIDA, PENDIENTE DE RATIFICACIÓN**
* **Decisión:** si `selectedTests` está vacío o no existe, incluido el caso sin documento `users/{uid}`, `GET /practice/next` responde 404 con `NO_QUESTIONS_AVAILABLE`, `field: "selectedTests"` y `details: { "reason": "NO_TESTS_SELECTED" }`. El cliente reconoce el caso por `field` y lleva al estudiante a elegir sus pruebas en vez de mostrar el banco vacío, como pide la regla de negocio 8.
* **Alternativas descartadas:** servir preguntas de todas las pruebas con banco contradice la regla de negocio 7, que solo permite preguntas de las pruebas seleccionadas. Un código de error nuevo cambiaría el catálogo del contrato v1.0, que es de la empresa. `BUSINESS_RULE_VIOLATION` es genérico: el cliente igual necesitaría `details` para saber a qué pantalla ir.
* **Impacto:** el cliente tiene que leer `field` en `NO_QUESTIONS_AVAILABLE`. Cuando las pruebas elegidas ya no tienen preguntas pendientes, la respuesta es la misma sin `field` ni `details`.
