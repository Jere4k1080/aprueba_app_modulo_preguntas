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
20. [ADR-20: JWT_SECRET obligatorio en producción (Sustituida por ADR-40)](#adr-20-jwt_secret-obligatorio-en-producción)
21. [ADR-21: Firestore accesible solo desde la API](#adr-21-firestore-accesible-solo-desde-la-api)
22. [ADR-22: Confirmación para ejecutar el seed remoto](#adr-22-confirmación-para-ejecutar-el-seed-remoto)
23. [ADR-23: Recálculo diario del percentil con Vercel Cron](#adr-23-recálculo-diario-del-percentil-con-vercel-cron)
24. [ADR-24: Ubicación de Firestore para el proyecto de desarrollo](#adr-24-ubicación-de-firestore-para-el-proyecto-de-desarrollo)
25. [ADR-25: Ubicación de Firestore y región de la API aplicadas](#adr-25-ubicación-de-firestore-y-región-de-la-api-aplicadas)
26. [ADR-26: Preset Express y despliegues de Git solo desde main](#adr-26-preset-express-y-despliegues-de-git-solo-desde-main)
27. [ADR-27: Cuota y preferencias en `users/{uid}` según el modelo de la empresa](#adr-27-cuota-y-preferencias-en-usersuid-según-el-modelo-de-la-empresa)
28. [ADR-28: Supuesto sobre preferencias y cuota que el modelo de la empresa no define](#adr-28-supuesto-sobre-preferencias-y-cuota-que-el-modelo-de-la-empresa-no-define)
29. [ADR-29: Respuesta de `GET /practice/next` sin pruebas seleccionadas](#adr-29-respuesta-de-get-practicenext-sin-pruebas-seleccionadas)
30. [ADR-30: Backend en FastAPI](#adr-30-backend-en-fastapi)
31. [ADR-31: Convenciones del backend de administración](#adr-31-convenciones-del-backend-de-administración)
32. [ADR-32: Código `METHOD_NOT_ALLOWED` para el 405 (Propuesta)](#adr-32-código-method_not_allowed-para-el-405)
33. [ADR-33: Cuerpos JSON en modo estricto, con tope de 100 kB y `PAYLOAD_TOO_LARGE` (Propuesta)](#adr-33-cuerpos-json-en-modo-estricto-con-tope-de-100-kb-y-payload_too_large)
34. [ADR-34: Error 500 dentro de CORS (Propuesta)](#adr-34-error-500-dentro-de-cors)
35. [ADR-35: `HEAD` en `/health` (Propuesta)](#adr-35-head-en-health)
36. [ADR-36: `APP_ENV` obligatorio en Vercel y Cloud Run (Propuesta)](#adr-36-app_env-obligatorio-en-vercel-y-cloud-run)
37. [ADR-37: Umbral no numérico en `calculate_cohort_percentile` (Propuesta)](#adr-37-umbral-no-numérico-en-calculate_cohort_percentile)
38. [ADR-38: Claims que `get_current_user` no verifica (Propuesta, sustituida por ADR-40)](#adr-38-claims-que-get_current_user-no-verifica)
39. [ADR-39: Solicitud previa de CORS con Starlette (Propuesta)](#adr-39-solicitud-previa-de-cors-con-starlette)
40. [ADR-40: Autenticación con Firebase Auth](#adr-40-autenticación-con-firebase-auth)
41. [ADR-41: Cambio de alcance autorizado: login y registro](#adr-41-cambio-de-alcance-autorizado-login-y-registro)
42. [ADR-42: Configuración de cliente de Firebase versionada](#adr-42-configuración-de-cliente-de-firebase-versionada)
43. [ADR-43: `verify_id_token` sin revisar revocación (Aceptada)](#adr-43-verify_id_token-sin-revisar-revocación)
44. [ADR-44: Rol y plan desde custom claims mientras `users` está en pausa (Propuesta)](#adr-44-rol-y-plan-desde-custom-claims-mientras-users-está-en-pausa)
45. [ADR-45: `CertificateFetchError` como 503 `SERVICE_UNAVAILABLE` (Propuesta)](#adr-45-certificatefetcherror-como-503-service_unavailable)
46. [ADR-46: Espera de 10 s para los certificados de Google (Propuesta)](#adr-46-espera-de-10-s-para-los-certificados-de-google)
47. [ADR-47: Tolerancia de 5 s en el reloj al verificar tokens (Propuesta)](#adr-47-tolerancia-de-5-s-en-el-reloj-al-verificar-tokens)
48. [ADR-48: `TypeError` de `firebase_admin` como 401 y `ValueError` como 500 (Propuesta)](#adr-48-typeerror-de-firebase_admin-como-401-y-valueerror-como-500)
49. [ADR-49: Firebase Admin con la configuración de Firestore (Propuesta, con el proyecto local decidido)](#adr-49-firebase-admin-con-la-configuración-de-firestore)
50. [ADR-50: `FIREBASE_AUTH_EMULATOR_HOST` solo en local con el emulador de Firestore (Propuesta)](#adr-50-firebase_auth_emulator_host-solo-en-local-con-el-emulador-de-firestore)
51. [ADR-51: Usuario opcional con cabecera inválida (Propuesta)](#adr-51-usuario-opcional-con-cabecera-inválida)
52. [ADR-52: `onSessionExpired` idempotente con el logout de ajustes (Propuesta)](#adr-52-onsessionexpired-idempotente-con-el-logout-de-ajustes)
53. [ADR-53: Cierre de sesión cuando Firebase invalida la cuenta al renovar (Propuesta)](#adr-53-cierre-de-sesión-cuando-firebase-invalida-la-cuenta-al-renovar)
54. [ADR-54: Arranque sin sesión si Firebase no carga (Propuesta)](#adr-54-arranque-sin-sesión-si-firebase-no-carga)
55. [ADR-55: Códigos de error de Firebase Auth en la app (Propuesta)](#adr-55-códigos-de-error-de-firebase-auth-en-la-app)

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
* **Actualización (2026-09-23):** con FastAPI (ADR-30) la función es `sanitize_question()`, en `backend/app/services/questions.py`. La decisión no cambia.

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
* **Actualización (2026-09-23):** ADR-30 reemplaza Express por FastAPI. El proyecto de Vercel separado se mantiene, con `app/main.py` en vez de `src/app.js`.

---

### ADR-18: Cuenta de servicio de Firebase en base64

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** `FIRESTORE_EMULATOR_HOST` tiene prioridad. Fuera del emulador, `FIREBASE_SERVICE_ACCOUNT_BASE64` entrega el JSON a `admin.credential.cert()`. Sin ninguna de las dos variables, la API falla al iniciar. Se reutiliza la instancia de Firebase Admin cuando ya existe.
* **Alternativa descartada:** depender de un archivo JSON mediante `GOOGLE_APPLICATION_CREDENTIALS` o aceptar credenciales predeterminadas de forma implícita.
* **Motivo:** Vercel recibe secretos por variables de entorno. El base64 conserva los saltos de línea de la cuenta de servicio y el fallo explícito evita iniciar contra un proyecto distinto al previsto.
* **Actualización (2026-09-23):** con FastAPI (ADR-30) ya no hay Firebase Admin. `backend/app/db/firestore.py` decodifica la variable y crea un único `AsyncClient` de `google-cloud-firestore` con las credenciales de la cuenta de servicio. La prioridad del emulador y el fallo al iniciar se mantienen. La decodificación acepta, como `Buffer.from` en Node, el valor sin relleno y el alfabeto URL seguro. Un `FIRESTORE_EMULATOR_HOST` vacío cuenta como ausente. En Cloud Run también se exige esta variable, sin credenciales predeterminadas.
* **Actualización (2026-09-24):** Firebase Admin vuelve al backend, solo para verificar los tokens de Firebase Auth (ADR-40). Usa la misma variable y la misma decodificación que Firestore, y la misma prioridad del emulador (ADR-49).

---

### ADR-19: CORS por lista de orígenes y patrón

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** `ALLOWED_ORIGINS` contiene orígenes exactos separados por comas. `ALLOWED_ORIGIN_PATTERN` admite una expresión regular opcional para vistas previas de Vercel. Las solicitudes `OPTIONS` reciben respuesta sin habilitar credenciales. Se reutiliza `cors` 2.8.6, que ya estaba en el lockfile, y se fija su versión exacta.
* **Alternativa descartada:** `cors()` sin restricciones y una lista fija de cada URL de vista previa.
* **Motivo:** el origen de producción es estable y las URLs de vista previa cambian en cada despliegue. `Authorization` viaja en una cabecera, sin cookies.
* **Actualización (2026-09-23):** con FastAPI (ADR-30) la lista y el patrón pasan al `CORSMiddleware` de Starlette y el paquete `cors` sale del proyecto. La solicitud previa permitida responde 200 en vez de 204 (ADR-39).

---

### ADR-20: JWT_SECRET obligatorio en producción

* **Estado:** **IMPLEMENTADA, PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** la carga de configuración falla cuando `NODE_ENV=production` y falta `JWT_SECRET`. El valor de desarrollo solo sirve fuera de producción.
* **Alternativa descartada:** conservar el secreto público de respaldo en producción.
* **Motivo:** ese valor está versionado como ejemplo y permitiría firmar tokens válidos si el operador omite la variable.
* **Actualización (2026-09-23):** con FastAPI (ADR-30) la condición es `APP_ENV=production`, porque `NODE_ENV` ya no se lee. `Settings` corta el arranque si `JWT_SECRET` falta o tiene solo espacios. No exige el largo mínimo de 32 bytes que pide Max (ADR-31).
* **Actualización (2026-09-24):** sustituida por ADR-40. El backend verifica tokens de Firebase Auth y ya no firma ni verifica JWT propios. `JWT_SECRET` salió de `Settings` y de `backend/.env.example`, y la API ya no la exige en producción.

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
* **Actualización (2026-09-23):** con FastAPI (ADR-30) el seed se corre con `python -m app.seed` desde `backend/`, en vez de `npm run seed`. La regla no cambia: sin emulador exige `SEED_ALLOW_REMOTE` y termina con código 1 antes de abrir Firestore. Como ahora es un booleano de pydantic, la variable acepta `true`, `1`, `yes`, `on`, `t` o `y`, sin distinguir mayúsculas. Node solo aceptaba el texto `true`.

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
* **Actualización (2026-09-23):** ADR-30 cambia el preset a `"framework": "fastapi"`. `git.deploymentEnabled` sigue igual.

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
* **Actualización (2026-09-23):** con las convenciones de ADR-31, `details` es una lista de objetos `{field, message, type}` y no un objeto. Al implementar la ruta, `{ "reason": "NO_TESTS_SELECTED" }` tiene que pasar a un elemento de esa lista, por ejemplo con `type: "NO_TESTS_SELECTED"`. Se ratifica junto con esta ADR.

---

### ADR-30: Backend en FastAPI

* **Estado:** **DECIDIDA POR LA CONTRAPARTE (2026-09-23), IMPLEMENTADA EN `feature/backend-fastapi`, PENDIENTE DE REVISIÓN CRUZADA**
* **Fuente:** decisión de Max, de Alloxentric, comunicada el 23/09/2026. El backend del módulo se escribe en FastAPI, el framework del backend de administración de la consola. Max decidió también que la autenticación será Firebase Auth. Eso llega en una entrega posterior y tendrá su propia ADR.
* **Decisión:** reemplazar el backend Node y Express por Python 3.12 y FastAPI en `backend/app/`. Esta entrega porta el andamiaje sin agregar funcionalidad: el health, el envelope, el catálogo de errores, la verificación de JWT, `sanitize_question()`, `calculate_cohort_percentile()` y el seed. No cambia la forma de las colecciones ni los datos del seed. Comparado en el emulador, el seed de Python escribe los mismos documentos que `seed.js`, con los mismos campos y tipos. Las diez pruebas de `health.test.js` están portadas en `backend/tests/test_health.py`, y `backend/tests/test_core.py` agrega 14.
* **Alternativa descartada:** seguir con Node y Express. Funcionaba y estaba desplegado, pero el backend de administración está en FastAPI. Con dos stacks, el envelope, el catálogo de errores, la paginación y la configuración se escribirían dos veces y podrían divergir.
* **Consecuencias:**
  * Sustituye el Express de ADR-17. `app/main.py` exporta `app` y `python -m app` escucha en local. El proyecto de Vercel separado sigue igual.
  * Sustituye el preset de ADR-26. `backend/vercel.json` declara `"framework": "fastapi"`, la región `gru1` y `app/main.py` como función. `git.deploymentEnabled` no cambia.
  * Se agrega `backend/Dockerfile` para Cloud Run, el destino del backend de administración. Vercel sigue siendo el destino activo y el servicio de Cloud Run no existe todavía.
  * `APP_ENV` (`local | staging | production`) reemplaza a `NODE_ENV`. En Vercel se creó el 2026-09-24, antes del primer despliegue (ADR-36).
  * ADR-12 sigue vigente con `sanitize_question()` en `backend/app/services/questions.py`. ADR-19 sigue vigente con el `CORSMiddleware` de Starlette en vez del paquete `cors`.
  * ADR-21 no cambia. El cliente `google-cloud-firestore` con la cuenta de servicio tampoco pasa por las reglas, como Firebase Admin.
  * Diferencias con Node que no son decisiones: Starlette distingue mayúsculas en las rutas y responde 307 a una ruta con barra final. `uptimeSeconds` cuenta desde que se importa el router. Salvo `seed/`, los subpaquetes de `app/` no tienen `__init__.py` y funcionan como paquetes de espacio de nombres. Si Vercel los rechaza, basta con agregar archivos vacíos.
* **Actualización (2026-09-24):** la entrega de Firebase Auth quedó en ADR-40. La verificación de JWT que portó esta ADR ya no existe.

---

### ADR-31: Convenciones del backend de administración

* **Estado:** **ADOPTADA EN PARTE (2026-09-23), PENDIENTE DE REVISIÓN CRUZADA**
* **Fuente:** "Aprueba, Consola de administración, Especificación de endpoints del backend (FastAPI)", versión 1.0 de septiembre de 2026, escrita por Max. Se revisaron las secciones 1.2, 2.1 a 2.9 y 9.4. El resto del documento describe endpoints de la consola, que están fuera del alcance.
* **Adoptado:**
  * La estructura de `app/` de la sección 2.2: `main.py` con `create_app()`, `core/`, `db/firestore.py` con un `AsyncClient` único y la clase `COL`, `services/`, `schemas/` y `routers/`.
  * El envelope `{data, error, meta}` con `ok()`, `created()`, `no_content()` y `meta()` (2.3).
  * `ApiError` con la firma de Max y el catálogo `MESSAGES` en español e inglés, indexado por `error.code`. `retry_after` pasa a `meta.retryAfter` (2.3).
  * Los diez errores estándar de la sección 2.5, con sus status y sus mensajes. Reemplazan los textos de `catalog.js`.
  * `RequestValidationError` como 400 `VALIDATION_ERROR`, con un elemento `{field, message, type}` por campo en `details` (2.3).
  * `details` como lista, vacía por defecto. En Node valía `null`.
  * `requestId` con `req_` y 12 caracteres hexadecimales, siempre generado en el servidor. Node reutilizaba el `X-Request-Id` del cliente.
  * El idioma por `Accept-Language`, español por defecto, con el mismo `app/core/i18n.py` de la sección 2.4.
  * `CamelModel` igual al de Max, en `app/schemas/common.py`. Los modelos usan snake_case en Python y el JSON sale en camelCase (1.2).
  * Fechas ISO 8601 en UTC con `Z` (1.2).
  * La paginación por cursor de la sección 2.7: `limit` 20 por defecto y 100 como máximo, cursor base64url con `v` e `id`, orden estable con `__name__`, `limit + 1` y `meta.pagination` con `total` por `count()`.
  * `APP_ENV` con `local | staging | production` y `FIRESTORE_EMULATOR_HOST` solo en local (2.9).
  * La documentación OpenAPI apagada en producción (9.4).
  * Un worker de Uvicorn por instancia en Cloud Run (2.1).
  * El 500 sin detalles para el cliente y registrado en el log con su `requestId` (2.5).
  * Pruebas con pytest contra el emulador de Firestore (9.4).
* **Adaptado, con motivo:**
  * Rutas en `/api/v1` y documentación en `/api/v1/docs`, no en `/api/v1/admin`. Este backend sirve al estudiante, no a la consola.
  * Versiones exactas con `==` en vez de mínimos con `>=`, por la regla 4 de `CLAUDE.md`. Todas cumplen los mínimos de Max. Se agregan fijas `starlette` y `google-auth`, que `app/` importa directo. `tzdata` entra para que `zoneinfo` funcione en Windows.
  * `PyJWT` sin el extra `[crypto]`. HS256 solo usa HMAC, que viene en la biblioteca estándar.
  * `get_current_user` en vez de `get_current_admin` y `require_role`. Es el port de `auth.js` de Node y no revisa roles administrativos ni los claims `typ` e `iss`. Nada lo usa todavía y Firebase Auth lo reemplaza (ADR-38).
  * En la validación, `field` vale `null` y no texto vacío cuando el error afecta al cuerpo completo. De `loc` se quitan también `header` y `cookie`. Un texto vacío en `field` se confunde con un campo sin nombre.
  * `meta.timestamp` con milisegundos, como `toISOString()` en Node. El `isoformat()` de Max da microsegundos y omite la fracción cuando vale cero, así que el ancho cambiaba entre respuestas.
  * `ok()` pasa a UTC con `Z` los `datetime` que vienen dentro de un dict y los `Timestamp` de Firestore. Sin eso, la regla de fechas de la sección 1.2 solo se cumplía dentro de un `CamelModel`.
  * El `requestId` se genera una vez por petición en `RequestIdMiddleware` y también sale en la cabecera `X-Request-Id`. En el código de Max, cada llamada a `meta()` generaba uno nuevo.
  * Un cursor corrupto da 400 `VALIDATION_ERROR` con `field: "cursor"`, no `INVALID_CURSOR`. Ese código no está en el catálogo de la sección 2.5 y Max le da mensaje recién en las fichas de sponsors y usuarios (secciones 5 y 7), que son de la consola. El cursor recuerda si el valor era una fecha, porque Firestore ordena primero por tipo y una fecha enviada como texto perdía o repetía páginas. Se reprodujo contra el emulador. El cursor se decodifica antes de `count()`.
  * CORS con `allow_credentials=False` y el patrón `ALLOWED_ORIGIN_PATTERN` para las vistas previas, por ADR-19. Max usa `allow_credentials=True`, pero aquí el token viaja en `Authorization` y no hay cookies.
  * En producción se apaga también `/api/v1/openapi.json`. Max solo apagaba `docs_url` y el esquema seguía público.
  * Credenciales por `FIREBASE_SERVICE_ACCOUNT_BASE64` y `FIREBASE_PROJECT_ID`, en vez de las credenciales predeterminadas de Google Cloud y `GCLOUD_PROJECT`. Vercel no tiene credenciales predeterminadas (ADR-18).
  * Pruebas con el `TestClient` de Starlette, que es síncrono, en vez de `httpx.AsyncClient`. Solo la prueba de paginación usa el emulador, porque las demás no tocan Firestore. La matriz de roles de la sección 9.4 no aplica sin roles administrativos.
  * Vercel sigue como destino activo y Cloud Run queda preparado con `backend/Dockerfile` (ADR-30).
  * `ApiError` rechaza un código del catálogo con un status distinto del suyo. En el código de Max cualquier combinación pasaba.
  * Se agrega un manejador para las `HTTPException` de Starlette. Sin él, una ruta inexistente respondía `{"detail": "Not Found"}` fuera del envelope, contra lo que pide la sección 2.3.
  * `GET /health` declara `response_model` solo para documentar el envelope en OpenAPI. Max no usa `response_model` en ninguna ruta.
* **No adoptado, con motivo:**
  * `core/security.py`, bcrypt, TOTP, `slowapi` y el login administrativo. El módulo no tiene login propio y la autenticación pasa a Firebase Auth.
  * `db/audit.py` y la colección `auditLog`. El módulo no hace escrituras administrativas.
  * Los servicios de Cloud Monitoring, Cloud Run, Stripe, medallas y notificaciones, con sus paquetes `google-cloud-monitoring`, `google-cloud-run`, `stripe`, `passlib` y `pyotp`. Son funciones de la consola. `httpx` queda solo como dependencia de desarrollo.
  * El manejador de `RateLimitExceeded` con `TOO_MANY_ATTEMPTS`. El módulo no limita peticiones.
  * Las variables `JWT_ACCESS_TTL`, `JWT_REFRESH_TTL`, `GCLOUD_PROJECT`, `CLOUD_RUN_REGION`, `STRIPE_SECRET_KEY`, `NOTIFICATIONS_URL` y `LOGIN_RATE_LIMIT`. Se conservan `JWT_EXPIRES_IN` y `REFRESH_TOKEN_EXPIRES_IN` de Node, porque ningún código emite tokens y Firebase Auth los vuelve innecesarios.
  * `JWT_SECRET` de 32 bytes como mínimo (2.9). En producción solo se rechaza vacío. Comprobar antes el largo del valor de Vercel obliga a descifrar un secreto, y Firebase Auth deja la variable sin uso. Node tampoco lo exigía. Si el equipo lo quiere antes, alguien con acceso confirma el largo y se agrega el control.
  * Las colecciones de la sección 2.8 y la forma que Max da a `users`, `corrections`, `questions` y las medallas. Max usa `state`, `resolvedBy`, `resolvedAt` y `rewardGranted` en `corrections`, el prefijo `qst_` en `questions` y la colección raíz `medalTransactions`. El módulo sigue con `status`, `reviewedBy`, `reviewedAt` y `potentialReward`, el prefijo `q_` y `users/{uid}/medalLedger` (ADR-01). El cambio está en pausa por instrucción del equipo hasta acordar un modelo único con Max.
* **Alternativa descartada:** copiar el andamiaje de Max completo, que traía dependencias y colecciones de la consola que el módulo no usa. También se descartó conservar las convenciones de Node (`details` en `null`, mensajes de `catalog.js`, `requestId` del cliente, traza visible en development). Max declara el mismo contrato de la empresa que sigue el módulo, y dos lecturas distintas del envelope en la misma base harían divergir a los clientes.
* **Consecuencias:** ADR-29 define `details` como objeto y con esta convención tiene que ser una lista. Lo que no cubren el documento de Max ni el encargo de esta entrega quedó como propuesta en ADR-32 a ADR-39.
* **Actualización (2026-09-24):** con ADR-40 salieron `PyJWT`, `JWT_SECRET`, `JWT_EXPIRES_IN` y `REFRESH_TOKEN_EXPIRES_IN`. Los puntos de esta ADR sobre `PyJWT` sin `[crypto]`, el port de `get_current_user` y el largo de `JWT_SECRET` quedaron sin objeto. `get_current_user` verifica ahora el ID token de Firebase. El mensaje de `AUTH_TOKEN_EXPIRED` dejó de ser el de la sección 2.5, que remite al refresh token de la consola. Los otros nueve errores estándar conservan el texto de Max.

---

### ADR-32: Código `METHOD_NOT_ALLOWED` para el 405

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** un método no soportado en una ruta existente responde 405 con el envelope y el código nuevo `METHOD_NOT_ALLOWED`. Un `OPTIONS` sin `Origin` también da 405. En `/health` la cabecera `Allow` dice solo `GET` aunque `HEAD` responde 200, porque Starlette informa la primera ruta que calza.
* **Alternativas descartadas:** responder 404 `NOT_FOUND`, como Node, que confunde un método equivocado con una ruta mal escrita. Sin un código para el 405 en el catálogo, el manejador de `app/core/errors.py` habría respondido 405 con `code: "INTERNAL_ERROR"`.
* **Motivo:** la sección 2.5 de Max no tiene código para el 405, y CLAUDE.md tampoco lo lista.
* **Impacto si se rechaza:** hay que quitar el código de `MESSAGES` y `ERROR_STATUS` en `app/core/errors.py` y decidir qué código lleva el 405. `test_405_metodo_no_permitido_con_envelope` cambia.

---

### ADR-33: Cuerpos JSON en modo estricto, con tope de 100 kB y `PAYLOAD_TOO_LARGE`

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** `JsonBodyMiddleware` revisa antes del enrutamiento el cuerpo de un POST, PUT o PATCH con `Content-Type: application/json`. Sigue el modo estricto de `express.json()`: solo acepta un objeto o un arreglo, y rechaza `NaN` e `Infinity`. Un BOM UTF-8 inicial se admite. Un JSON inválido, o anidado más hondo que el límite de recursión de Python, da 400 `VALIDATION_ERROR` con un elemento de tipo `json_invalid` en `details`. Un cuerpo de más de 100 kB da 413 con el código nuevo `PAYLOAD_TOO_LARGE`. Se cuentan los bytes leídos y no `Content-Length`, así que nunca se leen más de 100 kB y un fragmento.
* **Alternativa descartada:** dejar que cada ruta valide el cuerpo con FastAPI y sin tope. Un cuerpo de 32 MB se leía entero antes de responder, en 1,48 s. Con el tope, responde 413 en 0,002 s.
* **Motivo:** el backend Node tenía el mismo tope por defecto de `express.json()`. Su JSON malformado respondía 500 en HTML con la traza, por un fallo en `errorHandler` (`res.sendError is not a function`). El 400 corrige eso, no lo replica.
* **Impacto si se rechaza:** se quita el tope y `PAYLOAD_TOO_LARGE` del catálogo. `test_json_malformado_400_antes_del_enrutamiento` cambia. El modo estricto se puede conservar aparte.

---

### ADR-34: Error 500 dentro de CORS

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** `UnhandledErrorMiddleware`, ubicado dentro de `CORSMiddleware`, convierte toda excepción no controlada en 500 `INTERNAL_ERROR` con el envelope. La respuesta lleva `Access-Control-Allow-Origin` y la app web puede leerla. El manejador de `Exception` de `install_error_handlers` queda de respaldo para lo que falle en `RequestIdMiddleware` o en CORS.
* **Alternativa descartada:** usar solo el manejador de `Exception` de la sección 2.3 de Max. Starlette lo ejecuta en su middleware más externo, fuera de CORS, y el 500 salía sin `Access-Control-Allow-Origin`. El navegador lo bloqueaba y la app veía un error de red.
* **Motivo:** en Express, `errorHandler` corría después de `cors()` y el 500 llevaba la cabecera.
* **Verificación:** `test_error_no_controlado_500_sin_trazas` revisa la cabecera y que la respuesta no traiga la traza.

---

### ADR-35: `HEAD` en `/health`

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** `HEAD /api/v1/health` responde 200 sin cuerpo. Se registra con `@router.head` e `include_in_schema=False`, para no duplicar la operación en OpenAPI.
* **Alternativa descartada:** dejar solo `GET`, con lo que `HEAD` daría 405.
* **Motivo:** Express atiende `HEAD` en toda ruta `GET`, y un monitor de disponibilidad que use `HEAD` habría empezado a fallar con el cambio de stack.
* **Efecto secundario:** la cabecera `Allow` del 405 dice solo `GET` (ADR-32). `test_head_en_health_como_express` lo cubre.

---

### ADR-36: `APP_ENV` obligatorio en Vercel y Cloud Run

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23). LA VARIABLE YA EXISTE EN VERCEL (2026-09-24)**
* **Decisión tomada al portar:** `APP_ENV` acepta `local | staging | production` y vale `local` por defecto. Si existe `VERCEL` o `K_SERVICE` y `APP_ENV` no está definida, `Settings` corta el arranque con "APP_ENV es obligatorio en Vercel y en Cloud Run.". Cualquier otro valor, como `development`, también lo corta.
* **Alternativa descartada:** usar `local` por defecto en todas partes. Un despliegue sin la variable correría como local, con `/api/v1/docs` público y el health informando `local`.
* **Motivo:** Max define los valores de `APP_ENV` pero no qué pasa cuando falta. Vercel define `VERCEL=1` al ejecutar la función y Cloud Run define `K_SERVICE`, así que el control solo actúa en esas plataformas.
* **Acción previa a la fusión:** hecha el 2026-09-24. `APP_ENV=production` existe en production y en preview del proyecto de Vercel `aprueba-app-modulo-preguntas-api`. Para preview el equipo eligió `production` y no `staging`. La API en Node no la lee y siguió respondiendo 200 en `/health`. Queda borrar `NODE_ENV` al desplegar FastAPI, y definir `APP_ENV` en el servicio de Cloud Run cuando exista.
* **Límite conocido:** si el proyecto de Vercel apagara la exposición de variables de sistema, `VERCEL` no existiría y el control no actuaría. `test_app_env_obligatorio_en_vercel_y_cloud_run` cubre los dos casos.

---

### ADR-37: Umbral no numérico en `calculate_cohort_percentile`

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** en `backend/app/services/questions.py`, un umbral que falta o que no es numérico, incluido `null`, toma su valor por defecto: `p25` 15 000 ms, `p50` 25 000 ms, `p75` 45 000 ms y `p90` 60 000 ms. Si `thresholds` no es un dict o `elapsed_ms` no es un número, el resultado es 50. Un booleano no cuenta como número.
* **Alternativa descartada:** replicar Node, que comparaba un `null` como si fuera 0 y convertía los textos a número. Con `{p25: null}` y 10 000 ms, Node daba 75. Ahora da 90.
* **Motivo:** un documento de `questions` mal cargado no debe terminar en 500 cuando el estudiante responde. ADR-10 no dice qué hacer con umbrales inválidos.
* **Impacto:** el percentil solo cambia cuando el documento trae umbrales inválidos. `test_02_calculate_cohort_percentile` lo cubre.

---

### ADR-38: Claims que `get_current_user` no verifica

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23). VIGENTE HASTA LA ENTREGA DE FIREBASE AUTH**
* **Decisión tomada al portar:** `get_current_user`, en `backend/app/core/deps.py`, es el port de `auth.js`. Acepta solo HS256 y no verifica `aud`, `sub`, `jti` ni un `iat` futuro, igual que `jsonwebtoken`. Un token vencido da 401 `AUTH_TOKEN_EXPIRED`. Sin token o con firma inválida da 401 `AUTH_REQUIRED`. El esquema `bearer` se acepta sin importar mayúsculas.
* **Alternativas descartadas:** dejar las verificaciones por defecto de PyJWT, que rechazan un `aud` no pedido y un `sub` o un `jti` que no sean texto. Tokens que Node aceptaba habrían dado 401. También se descartó el `decode()` de Max, que exige `iss: "aprueba-admin"` y `typ`, claims de los tokens de la consola.
* **Motivo:** ninguna ruta usa la dependencia todavía y Firebase Auth la reemplaza. Mientras tanto acepta lo mismo que aceptaba Node.
* **Diferencias con Node:** `jsonwebtoken` aceptaba también HS384 y HS512, y exigía `Bearer ` con mayúscula. `test_get_current_user` cubre los casos.
* **Actualización (2026-09-24):** sustituida por ADR-40. `get_current_user` ya no decodifica JWT con HS256: valida el ID token de Firebase con `verify_id_token`, que revisa firma, `aud`, `iss`, `sub`, `iat` y `exp`. `test_get_current_user` se reemplazó por las pruebas de ADR-40.

---

### ADR-39: Solicitud previa de CORS con Starlette

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-23)**
* **Decisión tomada al portar:** se usa el `CORSMiddleware` de Starlette 1.7.0 sin cambios. Una solicitud previa permitida responde 200 en `text/plain`, con cuerpo `OK`, `Access-Control-Allow-Origin` igual al origen, `Access-Control-Max-Age` 600 y una cabecera `Vary` que incluye `Origin`, sin `Access-Control-Allow-Credentials`. Una de un origen no permitido responde 400 en `text/plain` con `Disallowed CORS origin`, sin envelope y sin `Access-Control-Allow-Origin`.
* **Alternativa descartada:** envolver el rechazo en el envelope o forzar 204. El navegador no expone el cuerpo de una solicitud previa, así que el cambio agregaba código sin efecto en el cliente.
* **Motivo:** Express respondía 204 a la permitida y 200 sin la cabecera a la rechazada. Para el navegador el resultado es el mismo en los dos casos.
* **Consecuencias:** la verificación del despliegue en `README.md` espera 200 y no 204. `allow_origin_regex` usa `re.fullmatch`, y Node usaba `RegExp.test`, que busca en cualquier parte. Con un patrón anclado, como el de Vercel, el resultado no cambia. Uno sin anclas dejaría pasar menos orígenes que en Node.

---

### ADR-40: Autenticación con Firebase Auth

* **Estado:** **DECIDIDA POR LA CONTRAPARTE (2026-09-23), IMPLEMENTADA EN `feature/firebase-auth`, PENDIENTE DE REVISIÓN CRUZADA**
* **Fuente:** decisión de Max, de Alloxentric, comunicada al equipo el 23/09/2026. Max firma su especificación del backend de administración como Wellq Co, pero esta decisión no está en ese documento: su sección 2.6 describe solo el login propio de la consola. ADR-30 ya la anunciaba. Ese mismo día la contraparte autorizó sacar la verificación por SMS del registro.
* **Decisión en el backend:**
  * `get_current_user`, en `backend/app/core/deps.py`, valida el ID token de Firebase con `firebase_admin.auth.verify_id_token`. La llamada corre en `run_in_threadpool`, porque bloquea mientras baja los certificados públicos de Google.
  * Un token vencido da 401 `AUTH_TOKEN_EXPIRED`. Sin cabecera, con un esquema distinto de `Bearer`, con el token vacío o con un token rechazado da 401 `AUTH_REQUIRED`. Las dos respuestas llevan el envelope.
  * El mensaje de `AUTH_TOKEN_EXPIRED` en `backend/app/core/errors.py` pasó de "El token de acceso expiró; renuévalo con el refresh token." a "El token de acceso expiró. La app debe pedir uno nuevo a Firebase y reintentar.", con su versión en inglés. El alumno no tiene un refresh token propio: el token lo renueva el SDK de Firebase. Es el único de los diez errores estándar cuyo texto ya no es el de la sección 2.5 de Max, que remite al refresh token de la consola (ADR-31).
  * Firebase Admin sale de la misma configuración que Firestore y solo verifica tokens. Firestore sigue con el `AsyncClient` de `google-cloud-firestore` (ADR-30). `create_app()` llama a `get_firebase_app()` después de `get_db()`, así que la API no arranca sin `FIRESTORE_EMULATOR_HOST` ni `FIREBASE_SERVICE_ACCOUNT_BASE64` (ADR-49).
  * `backend/requirements.txt` cambia `PyJWT==2.15.0` por `firebase-admin==7.7.0`. La instalación solo agregó paquetes y no movió ninguna versión fijada. `pyjwt` 2.15.0 sigue instalado como dependencia de `firebase-admin`. `JWT_SECRET`, `JWT_EXPIRES_IN` y `REFRESH_TOKEN_EXPIRES_IN` salieron de `backend/app/core/config.py` y de `backend/.env.example`. El valor de desarrollo `DEV_JWT_SECRET`, que solo estaba en `config.py`, también salió.
* **Decisión en la app:**
  * `AuthRepository.login` inicia sesión con correo y contraseña mediante `signInWithEmailAndPassword`. Los errores de Firebase se traducen como indica ADR-55.
  * `ApiClient` adjunta en cada petición el ID token de Firebase y `Accept-Language` con el idioma elegido en la app, que se lee en el momento. Si el token no se puede obtener porque no hay red, la petición sale sin él y, cuando termina en `NETWORK_ERROR`, el repositorio sirve la caché.
  * Ante un 401, `ApiClient` pide un token nuevo con `getIdToken(forceRefresh: true)` y reintenta una sola vez. Los 401 simultáneos esperan la misma renovación. Si otra petición ya renovó, se usa ese token sin forzar otro.
  * Si el reintento vuelve a dar 401, o Firebase ya no tiene usuario, `onSessionExpired` ejecuta `AuthController.logout()`, el mismo del botón de ajustes. Ese método cierra la sesión de Firebase, borra `SecureStorage`, vacía Drift con `_db.wipe()` e invalida `meProvider`. Drift importa porque `CachedQuestions` guarda `correctAnswer` después de responder. Con `isLoggedIn` en falso el router lleva al inicio (ADR-52 y ADR-53).
  * `lib/main.dart` inicializa Firebase con `DefaultFirebaseOptions` (ADR-42) y toma la sesión inicial del primer evento de `authStateChanges` (ADR-54). Se borró `lib/core/storage/secure_storage_bootstrap.dart`, que buscaba el refresh token, y `lib/core/network/endpoints.dart` perdió `/auth/login`, `/auth/refresh` y `/auth/logout`.
* **Verificación por SMS:** los pasos de teléfono del registro (`/register`, `/onboarding/phone` y `/onboarding/verify-phone`) quedan detrás de `PHONE_VERIFICATION_ENABLED`, definida en `lib/core/config/app_config.dart` y apagada por defecto. Con la bandera apagada, el router lleva esas rutas a `/onboarding/locale`. El código de `PhoneAuthService` y de las pantallas de teléfono sigue en el repositorio. Con `--dart-define=PHONE_VERIFICATION_ENABLED=true` el registro vuelve a pedir y verificar el número.
* **Alternativa descartada:** JWT propio del backend, con un access token de 15 minutos y un refresh token de 30 días que rotaba en cada uso, como describían el párrafo de sesión de `CLAUDE.md` y la tabla de tecnologías de `README.md`. ADR-20 cubría su secreto de firma y ADR-38 su verificación. El backend tendría que emitir y rotar tokens y custodiar un secreto de firma. Ninguna ruta del backend FastAPI los emitía todavía, y la contraparte eligió Firebase Auth.
* **Sustituye:** ADR-20 (`JWT_SECRET` obligatorio en producción) y ADR-38 (claims que el port de `auth.js` no verificaba). Las dos conservan su texto, con una nota que remite aquí.
* **Consecuencias:**
  * Lo que esta entrega decidió sin cobertura del encargo ni del documento de Max quedó como propuesta en ADR-43 a ADR-55. El cambio de alcance en la app está en ADR-41 y la configuración de cliente de Firebase en ADR-42.
  * Ninguna ruta usa todavía `CurrentUser` ni `OptionalUser`. La API sigue respondiendo solo `/health`.
  * En el proyecto de Vercel de la API sobran `JWT_SECRET`, `JWT_EXPIRES_IN`, `REFRESH_TOKEN_EXPIRES_IN` y `NODE_ENV`. `Settings` ignora las variables que no declara, así que no impiden el arranque, pero hay que borrarlas al desplegar. `APP_ENV` ya existe desde el 2026-09-24 (ADR-36).
  * El registro de la app no crea cuentas (ADR-41). El 2026-09-24 el equipo habilitó el proveedor de correo y contraseña en Firebase Authentication del proyecto `aprueba-app-modulo-preguntas` y creó dos cuentas de demostración desde la consola. Leídas con el Admin SDK, las dos tienen el proveedor `password`, están activas y no traen custom claims, así que la API las trata como `student` con plan `free` (ADR-44). No tienen documento `users/{uid}` en Firestore, porque la forma de `users` está en pausa.
* **Verificación (2026-09-24):** `pytest` en `backend/` da 31 aprobadas con el emulador de Firestore, 21 en `tests/test_core.py` y 10 en `tests/test_health.py`. Antes eran 24. Las pruebas reemplazan `verify_id_token` con `monkeypatch`, salvo `test_verify_id_token_real_con_firma_local`, que firma tokens RS256 con una llave generada durante la prueba y reemplaza la descarga de certificados. Ninguna usa red ni credenciales reales. `flutter test` da 45 aprobadas. En `feature/backend-fastapi` eran 29, y las 16 nuevas están en `test/api_client_auth_test.dart`. `flutter analyze` sigue en 38 avisos informativos, sin advertencias ni errores.

---

### ADR-41: Cambio de alcance autorizado: login y registro

* **Estado:** **AUTORIZADA POR LA CONTRAPARTE (2026-09-23), IMPLEMENTADA EN `feature/firebase-auth`, PENDIENTE DE REVISIÓN CRUZADA**
* **Contexto:** `CLAUDE.md` deja fuera del alcance el registro y la autenticación, y dice que ese código es del cliente y no se toca. Pasar a Firebase Auth (ADR-40) obligaba a cambiar el login, que pedía tokens a `/auth/login` y los renovaba con `/auth/refresh`. El 23/09/2026 Alloxentric autorizó tocar lo necesario para ese cambio y sacar la verificación por SMS.
* **Archivos tocados fuera de `lib/features/practice/`:**
  * `lib/core/network/api_client.dart`: el interceptor adjunta el ID token de Firebase y `Accept-Language`, renueva una vez ante un 401 y cierra la sesión cuando no puede.
  * `lib/providers/app_providers.dart`: crea `ApiClient` con el token y el idioma, y conecta `onSessionExpired` con `AuthController.logout()` (ADR-52).
  * `lib/providers/auth_controller.dart`: `login` deja de devolver `AuthSession`, porque Firebase no entrega tokens del backend, y pasa el idioma de la app para los mensajes de error.
  * `lib/data/repositories/auth_repository.dart`: `login` usa `signInWithEmailAndPassword`, `logout` usa `signOut` de Firebase en vez de `/auth/logout` y `hasSession` mira `FirebaseAuth.instance.currentUser`. Agrega `authExceptionFromFirebase` (ADR-55).
  * `lib/core/l10n/app_strings.dart`: cinco textos de error del login, en español e inglés.
  * `lib/core/network/endpoints.dart`: quita `/auth/login`, `/auth/refresh` y `/auth/logout`, que ahora resuelve Firebase.
  * `lib/core/storage/secure_storage_bootstrap.dart`: se borró. Decidía si había sesión buscando el refresh token.
  * `lib/main.dart`: inicializa Firebase y lee de ahí la sesión inicial (ADR-54).
  * `lib/core/config/app_config.dart`: agrega `PHONE_VERIFICATION_ENABLED` y quita `accessTokenTtl`, la duración informativa de 15 minutos del token propio.
  * `lib/core/router/app_router.dart`: con la bandera apagada, `/register`, `/onboarding/phone` y `/onboarding/verify-phone` llevan a `/onboarding/locale`.
  * `lib/data/services/phone_auth_service.dart`: inicializa Firebase con las mismas opciones que `main.dart` y cierra la sesión de Firebase apenas obtiene el ID token del teléfono. Esa sesión solo probaba el número. Con Firebase Auth como sesión de la app, dejarla abierta habría dado sesión al alumno antes de terminar el registro. Solo corre con `PHONE_VERIFICATION_ENABLED=true`.
  * `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` y `.gitignore`: configuración de cliente de Firebase (ADR-42).
  * `test/api_client_auth_test.dart`, nuevo, y `test/drift_integrity_test.dart`, donde solo cambió la forma de construir `ApiClient`.
* **Sin tocar a propósito:** el registro (`lib/features/auth/register_screen.dart` y `POST /auth/register`), el login social (`lib/features/auth/social_buttons.dart`, `lib/data/services/social_auth_service.dart` y `POST /auth/social`), el olvido y el restablecimiento de contraseña (`forgot_password_screen.dart`, `/auth/password/forgot` y `/auth/password/reset`), el resto del onboarding, `SecureStorage` y el modelo `AuthSession`. Siguen llamando a rutas `/auth/*` que el backend FastAPI no tiene. `pubspec.yaml` no cambió: `firebase_auth` y `firebase_core` ya estaban.
* **Límites conocidos:**
  * Con `PHONE_VERIFICATION_ENABLED` apagada el registro no tiene salida. `RegisterScreen`, en `/onboarding/account`, exige `isPhoneVerified` y después llama a `/auth/register`. Aunque esa ruta existiera, `/auth/register` y `/auth/social` devuelven tokens propios del backend que el interceptor ya no envía. Las cuentas de demostración se crean desde la consola de Firebase.
  * `isLoggedInProvider` no escucha `authStateChanges` de Firebase. Si Firebase cierra la sesión por su cuenta, la app se entera con el siguiente 401 (ADR-53).
* **Alternativa descartada:** relajar `isPhoneVerified` en `register_screen.dart` para que el registro funcione sin teléfono. El registro igual terminaría en tokens propios del backend que el interceptor ya no usa, y rehacerlo sobre Firebase es otro cambio de alcance que la contraparte no autorizó.
* **Pendiente:** confirmar con Alloxentric qué pasa con el registro, el login social y el restablecimiento de contraseña. Una propuesta para esa conversación: mientras no pasen a Firebase, "Comenzar" (`lib/features/splash/splash_screen.dart:37`) lleva a `/login` y `SocialButtons` se oculta.

---

### ADR-42: Configuración de cliente de Firebase versionada

* **Estado:** **IMPLEMENTADA EN `feature/firebase-auth` (2026-09-24), PENDIENTE DE REVISIÓN CRUZADA**
* **Decisión:** se versiona la configuración de cliente del proyecto `aprueba-app-modulo-preguntas`: `lib/firebase_options.dart`, con las opciones de web, Android e iOS, más `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`. `.gitignore` dejó de excluir los dos últimos. Ahora ignora también `**/*-firebase-adminsdk-*.json`, el nombre con que la consola de Firebase descarga la llave de una cuenta de servicio, además de los nombres de cuenta de servicio que ya excluía.
* **Por qué la `apiKey` no es secreta:** identifica el proyecto ante las APIs de Google y viaja dentro de cualquier build de la app, así que cualquiera que tenga la app puede leerla. No da acceso a los datos: `firestore.rules` niega al cliente toda lectura y escritura (ADR-21), y la API solo acepta un ID token que `verify_id_token` haya validado (ADR-40). Con la `apiKey` sí se puede llamar a Firebase Authentication del proyecto, por ejemplo para crear una cuenta si el proveedor de correo lo permite. Esa cuenta queda autenticada, pero sigue sin poder leer Firestore. La API, en cambio, aceptaría su token como el de un alumno más, con rol `student` y plan `free`, porque `get_current_user` no lee `users/{uid}` (ADR-44).
* **Cuenta de servicio:** sigue siendo secreta. Llega al backend solo por `FIREBASE_SERVICE_ACCOUNT_BASE64` (ADR-18). No se versiona ni se imprime.
* **Búsqueda de secretos:** la regla 2 de `CLAUDE.md` excluye `firebase_options.dart`, `google-services.json` y `GoogleService-Info.plist`, porque el patrón de la búsqueda calza con el prefijo de su `apiKey` y los encontraría cada vez. También excluye `.dart_tool`, donde una compilación web deja la misma `apiKey` dentro de `main.dart.js`. La regla lista los archivos que siguen apareciendo y por qué.
* **Origen de `firebase_options.dart`:** se escribió a mano con el formato de FlutterFire CLI, a partir de los archivos que entrega la consola de Firebase. `flutterfire configure` lo reemplaza sin tocar el resto del código. En macOS, Windows y Linux lanza `UnsupportedError`, como hace FlutterFire con una plataforma que no se configuró.
* **Qué archivo se usa:** `lib/main.dart` y `PhoneAuthService` inicializan Firebase con `DefaultFirebaseOptions.currentPlatform`. Hoy ningún build nativo lee `google-services.json` ni `GoogleService-Info.plist`: Android no aplica el plugin `com.google.gms.google-services` y `ios/Runner.xcodeproj/project.pbxproj` no referencia el plist. `setup/android/build.gradle.notes.md` pide `google-services.json` para las notificaciones push, que están fuera del alcance. `setup/ios/Podfile.notes.md` pide el plist sin decir para qué.
* **Alternativa descartada:** dejar los archivos fuera del repositorio, como hacía `.gitignore`, y generarlos en cada máquina y en cada build de Vercel. Cada integrante tendría que conseguirlos aparte y `vercel-build.sh` necesitaría otra variable, sin proteger nada, porque la `apiKey` igual queda dentro de la app publicada.
* **Pendiente:** restringir las API keys en Google Cloud, por aplicación en Android e iOS y por referer en web. Decidir con Alloxentric si el alta de cuentas desde el cliente queda habilitada en Firebase Authentication.

---

### ADR-43: `verify_id_token` sin revisar revocación

* **Estado:** **ACEPTADA POR EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `get_current_user` llama a `verify_id_token` con `check_revoked=False`. Un token revocado, por un cambio de contraseña o por `revoke_refresh_tokens`, se sigue aceptando hasta que expira. Lo mismo pasa con el token de un usuario deshabilitado. Un ID token de Firebase dura una hora, así que esa es la ventana máxima.
* **Alternativa descartada:** `check_revoked=True`. Agrega una llamada a la API de Firebase Authentication en cada petición, con su latencia y su cuota. Esa llamada necesita credenciales, así que el modo emulador sin cuenta de servicio dejaría de funcionar (ADR-49).
* **Impacto si se rechaza:** hay que manejar `auth.UserDisabledError`, que no hereda de `InvalidIdTokenError` y hoy terminaría en 500 (ADR-48). `RevokedIdTokenError` sí hereda y daría 401 `AUTH_REQUIRED`. `test_token_de_firebase_valido_entrega_el_usuario` revisa los argumentos de la llamada y tendría que cambiar.
* **Aceptación (2026-09-24):** el equipo acepta la ventana. El retraso de hasta una hora en rechazar un token revocado queda cubierto cuando se implemente el rechazo de usuarios suspendidos.

---

### ADR-44: Rol y plan desde custom claims mientras `users` está en pausa

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `get_current_user` devuelve `uid`, `email`, `role` y `plan`. `uid` es el claim que `verify_id_token` copia de `sub`. `role` sale del custom claim `role` o vale `student`, y `plan` sale del custom claim `plan` o vale `free`. No lee `users/{uid}`.
* **Motivo:** la forma de `users` está en pausa por la contraparte hasta acordar un modelo único con Max (ADR-31). Leer el documento en cada petición sumaba un uso nuevo de esa colección.
* **Consecuencia:** nadie asigna custom claims hoy, así que todo alumno autenticado queda como `student` con plan `free`. Si una ruta usara `plan` para la regla de negocio 5, ningún alumno podría entrar al modo facsímil. Antes de implementar `FORMAT_REQUIRES_PLAN` hay que decidir de dónde sale el plan: de un custom claim que alguien asigne o de `users/{uid}`.
* **Alternativa descartada por ahora:** leer `users/{uid}` en cada petición y rechazar cuentas inexistentes o deshabilitadas, como `get_current_admin` en la sección 2.6 de Max. Queda para cuando `users` salga de pausa.
* **Verificación:** `test_token_de_firebase_valido_entrega_el_usuario` cubre los valores por defecto y los claims presentes.

---

### ADR-45: `CertificateFetchError` como 503 `SERVICE_UNAVAILABLE`

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** si `verify_id_token` no logra bajar los certificados públicos de Google, `get_current_user` responde 503 `SERVICE_UNAVAILABLE` con el envelope.
* **Alternativas descartadas:** 401 `AUTH_REQUIRED`, porque la app renovaría el token, recibiría otro 401 y cerraría la sesión del alumno por una caída de Google. Dejar que termine en 500 `INTERNAL_ERROR`, porque el problema está en un servicio externo y no es un defecto del backend.
* **Motivo:** la sección 2.5 de Max usa 503 cuando un servicio dependiente no responde a tiempo. Nombra Firestore, Cloud Monitoring, Cloud Run y Stripe, no los certificados de Google; esta ADR extiende el criterio. Un 503 no activa la renovación de `ApiClient`, que solo reacciona al 401.
* **Verificación:** `test_certificados_de_google_no_disponibles_da_503`.

---

### ADR-46: Espera de 10 s para los certificados de Google

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** Firebase Admin se inicia con `httpTimeout` en 10 segundos (`HTTP_TIMEOUT` en `backend/app/db/firestore.py`). `TokenVerifier` lee esa opción al bajar los certificados. Al vencer, `verify_id_token` lanza `CertificateFetchError` y la API responde 503 (ADR-45).
* **Alternativas descartadas:** los 120 s por defecto de `firebase_admin` (`_http_client.DEFAULT_TIMEOUT_SECONDS`). Dio corta a los 20 s, así que la app ya habría abandonado la petición, y el hilo del threadpool quedaba ocupado hasta 120 s. También se descartaron los 5 s que Max usa para Firestore: la descarga de certificados es esporádica y queda en caché.
* **Verificación:** `test_08_firebase_admin_con_la_configuracion_de_firestore` compara las opciones con `{"projectId": "aprueba-test", "httpTimeout": 10}`.

---

### ADR-47: Tolerancia de 5 s en el reloj al verificar tokens

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `verify_id_token` recibe `clock_skew_seconds=5`.
* **Alternativa descartada:** el valor por defecto, 0. `google-auth` compara segundos enteros y rechaza con "Token used too early" un token recién emitido si el reloj del servidor va algo atrasado respecto de Google. La app renovaría, recibiría otro 401 y cerraría la sesión del alumno.
* **Costo:** un token vencido se acepta hasta 5 s más. Es poco comparado con la hora que ya acepta un token revocado (ADR-43).
* **Verificación:** `test_verify_id_token_real_con_firma_local` acepta un token con `iat` 2 s en el futuro. Sin el parámetro fallan dos pruebas.

---

### ADR-48: `TypeError` de `firebase_admin` como 401 y `ValueError` como 500

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** en `get_current_user`, `ExpiredIdTokenError` se atrapa primero, porque hereda de `InvalidIdTokenError`, y da 401 `AUTH_TOKEN_EXPIRED`. `InvalidIdTokenError` y `TypeError` dan 401 `AUTH_REQUIRED`. `firebase_admin` 7.7.0 deja escapar `TypeError` con algunos tokens mal formados: el literal `eyJhbGciOiJIUzI1NiJ9.eyJ2IjowLCJkIjo1fQ.AAAA` respondía 500 con "argument of type int is not iterable", y un `kid` dentro de una lista también fallaba. Un `ValueError` no se atrapa y termina en 500, con el `requestId` en el log. `get_firebase_app()` se llama antes del `try`, para que un error al iniciar Firebase Admin tampoco se convierta en 401.
* **Alternativa descartada:** atrapar también `ValueError`, `RevokedIdTokenError` y `UserDisabledError` como 401. Con `check_revoked=False` los dos últimos no ocurren (ADR-43). Un `ValueError` solo viene de la configuración, por ejemplo sin ID de proyecto o con `FIREBASE_AUTH_EMULATOR_HOST` escrita con esquema. Con `FIREBASE_AUTH_EMULATOR_HOST=http://127.0.0.1:9099` la API respondía 401 sin dejar nada en el log, y la app cerraba la sesión.
* **Verificación:** `test_verify_id_token_real_con_firma_local` y `test_error_de_configuracion_en_verify_id_token_da_500`.

---

### ADR-49: Firebase Admin con la configuración de Firestore

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24). EL PROYECTO LOCAL LO DECIDIÓ EL EQUIPO EL MISMO DÍA**
* **Decisión tomada al implementar:**
  * `get_firebase_app()` vive en `backend/app/db/firestore.py`, junto a `get_db()`. La decodificación de `FIREBASE_SERVICE_ACCOUNT_BASE64` pasó a `_service_account_info()`, que usan los dos.
  * Con `FIRESTORE_EMULATOR_HOST`, Firebase Admin se inicia con `AnonymousCredentials()` de `google-auth` y el proyecto `FIREBASE_PROJECT_ID`, o `aprueba-app-modulo-preguntas` si falta. Verificar un token solo usa los certificados públicos, así que no hace falta una credencial.
  * Con cuenta de servicio, la credencial es `firebase_admin.credentials.Certificate` y el proyecto es `FIREBASE_PROJECT_ID` o el `project_id` del JSON, el mismo criterio que Firestore.
  * Si la app por defecto de Firebase ya existe, `get_firebase_app()` la devuelve, porque `create_app()` puede correr varias veces en un proceso. Se prefirió eso a una bandera a nivel de módulo, que quedaría desfasada cuando las pruebas borran la app con `delete_app`.
* **Alternativas descartadas:** `initialize_app(None)` en modo emulador. En `firebase_admin` 7.7.0 ese valor se convierte en `ApplicationDefault`, y el primer `verify_id_token` llama a `google.auth.default()`. En una máquina sin credenciales predeterminadas la API respondía 500. También se descartó ubicar la función en `core/security.py`, donde Max tiene la firma de JWT y las contraseñas de la consola. Habría duplicado la decodificación o importado `db/` desde `core/` de todos modos.
* **Consecuencia:** el proyecto de Firebase Admin es la audiencia (`aud`) que exige `verify_id_token`. La app pide sus tokens al proyecto `aprueba-app-modulo-preguntas`, así que un backend con otro proyecto los rechaza con 401 `AUTH_REQUIRED`.
* **Decisión del equipo sobre el proyecto local (2026-09-24):** en local, `FIREBASE_PROJECT_ID` es `aprueba-app-modulo-preguntas`, el mismo proyecto contra el que inicia sesión la app. El emulador se usa solo para Firestore. `backend/.env.example` trae ese valor, y `APP_PROJECT`, en `backend/app/db/firestore.py`, lo usa por defecto cuando la variable falta. Antes el valor local era `aprueba-dev`, con el que la API local rechazaba los tokens de la app. Se descartaron también una variable aparte para la audiencia y el emulador de Auth. Con esta decisión el emulador de Auth no forma parte del entorno local; ADR-50, que todavía lo admite en local, se revisa al ratificar las propuestas.
* **Efecto en el emulador:** el comando documentado sigue levantándolo como `demo-aprueba`. El emulador acepta el otro ID y guarda esos datos aparte. Cada petición deja en `firestore-debug.log` el aviso "Multiple projectIds are not recommended in single project mode", y su interfaz abre `demo-aprueba`, así que no muestra lo que carga el seed. Falta decidir si el emulador se levanta con el mismo ID.
* **Verificación:** `test_08_firebase_admin_con_la_configuracion_de_firestore` reemplaza `google.auth.default` por una función que falla. Si el modo emulador volviera a `initialize_app(None)`, la prueba fallaría. El 2026-09-24, con el emulador levantado como `demo-aprueba` y sin `FIREBASE_PROJECT_ID`, `python -m app.seed` dejó las 20 preguntas bajo `aprueba-app-modulo-preguntas` y ninguna bajo `demo-aprueba`.

---

### ADR-50: `FIREBASE_AUTH_EMULATOR_HOST` solo en local con el emulador de Firestore

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** si `FIREBASE_AUTH_EMULATOR_HOST` tiene valor y no se cumplen `APP_ENV=local` y `FIRESTORE_EMULATOR_HOST` a la vez, `get_firebase_app()` lanza `RuntimeError` y la API no arranca. El mensaje es "FIREBASE_AUTH_EMULATOR_HOST solo se admite con APP_ENV=local y FIRESTORE_EMULATOR_HOST.". `backend/tests/conftest.py` quita la variable del entorno para que las pruebas no hereden el emulador de Auth de quien las corre.
* **Motivo:** con esa variable, `firebase_admin` da el token por emulado y no verifica la firma. Contra el proyecto real, o en staging, aceptaría tokens falsificados.
* **Alternativas descartadas:** no poner la guarda, porque el fallo sería silencioso y significaría saltarse la autenticación. Revisar la variable solo cuando hay cuenta de servicio, que fue la primera versión: nada impedía el mismo estado en staging con el emulador de Firestore.
* **Verificación:** `test_08_firebase_admin_con_la_configuracion_de_firestore` revisa los casos rechazados y el permitido.

---

### ADR-51: Usuario opcional con cabecera inválida

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `get_optional_user` mira si la petición trae la cabecera `Authorization`. Sin ella devuelve `None`, el usuario anónimo. Si la cabecera existe pero no sirve, por ejemplo con el esquema `Basic` o con un token rechazado, responde el mismo 401 que `get_current_user`.
* **Alternativa descartada:** conservar el `None` que entrega `HTTPBearer(auto_error=False)`. Convertía una cabecera `Basic` o un `Bearer` vacío en un usuario anónimo, y un cliente con un error en la cabecera no se enteraba.
* **Impacto:** ninguna ruta usa `OptionalUser` todavía. `test_usuario_opcional` cubre los casos.

---

### ADR-52: `onSessionExpired` idempotente con el logout de ajustes

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** en `lib/providers/app_providers.dart`, `onSessionExpired` sale sin hacer nada si `isLoggedInProvider` ya es falso. Si no, baja la bandera y recién entonces llama a `AuthController.logout()`, el mismo método del botón de ajustes.
* **Hallazgo:** `AuthController.logout()` invalida `meProvider`. Sin sesión, el nuevo `/me` responde 401 sin token y vuelve a llamar a `onSessionExpired`. Con una sonda que usaba el `apiClientProvider` real y un adaptador que siempre respondía 401, hubo 515 peticiones y 514 logouts en 600 ms, cada uno con su borrado de Drift. Con la guarda hubo 2 peticiones y 1 logout. La misma guarda deja en un solo logout los 401 simultáneos cuyo reintento también falla.
* **Alternativas descartadas:** un `Future` compartido en `ApiClient` para la expiración. No corta el ciclo, porque cada `/me` es una petición nueva. Repetir `AuthRepository.logout()` más el cambio de `isLoggedIn` dentro del proveedor, que duplicaba la mitad de `AuthController.logout()`.
* **Consecuencia:** `app_providers.dart` y `auth_controller.dart` se importan entre sí. Dart lo permite, y el mismo patrón ya existe entre `app_providers.dart` y `local_prefs.dart`.
* **Verificación:** dos pruebas en `test/api_client_auth_test.dart`. Tres llamadas con sesión dan 1 logout y dejan `isLoggedIn` en falso, y una llamada sin sesión da 0. Las dos fallaban antes del cambio. Solo cubren el cableado: un `AuthController` espía cuenta los logouts. El borrado de Drift no se prueba de punta a punta porque `AuthRepository.logout` usa `FirebaseAuth.instance` sin inyección, y un paquete de mocks nuevo quedaba fuera de las reglas.

---

### ADR-53: Cierre de sesión cuando Firebase invalida la cuenta al renovar

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** si `getIdToken(forceRefresh: true)` lanza una excepción, `ApiClient` vuelve a pedir el token sin forzar. Si Firebase ya no tiene usuario, porque invalidó la cuenta y su SDK cerró la sesión, llama a `onSessionExpired` en ese momento. Sin red el usuario sigue existiendo, o la consulta lanza y se toma como token vacío, así que la sesión no se cierra.
* **Alternativa descartada:** esperar al siguiente 401, que llegaría sin token. Hasta que el alumno hiciera otra acción, `isLoggedIn` seguía en verdadero y Drift sin borrar.
* **Verificación:** "si Firebase invalidó la cuenta al renovar, cierra la sesión" falló antes del cambio. "si Firebase no logra renovar por red, no cierra la sesión" sigue en verde. Las dos están en `test/api_client_auth_test.dart`.

---

### ADR-54: Arranque sin sesión si Firebase no carga

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `lib/main.dart` espera hasta 10 s a `Firebase.initializeApp` y hasta 5 s al primer evento de `authStateChanges`. Si algo falla o vence, registra el error con `debugPrint` y la app arranca sin sesión. Pasa en web cuando `gstatic.com` está bloqueado y en escritorio, donde `DefaultFirebaseOptions` no tiene opciones.
* **Alternativa descartada:** dejar que la excepción suba desde `main()`. La app quedaba en blanco.
* **Consecuencia:** un alumno con sesión guardada ve la pantalla de inicio, y el login tampoco funciona mientras Firebase no cargue. La app no le explica por qué.

---

### ADR-55: Códigos de error de Firebase Auth en la app

* **Estado:** **PROPUESTA, PENDIENTE DE CONFIRMAR CON EL EQUIPO (2026-09-24)**
* **Decisión tomada al implementar:** `authExceptionFromFirebase`, en `lib/data/repositories/auth_repository.dart`, convierte cada error de Firebase Auth en una `ApiException` con un código estable y un mensaje de `app_strings.dart` en el idioma de la app. El código original de Firebase va en `details`. La tabla es:
  * `invalid-credential`, `INVALID_LOGIN_CREDENTIALS`, `wrong-password`, `user-not-found`, `missing-password` y `channel-error` pasan a `AUTH_INVALID_CREDENTIALS`. `channel-error` es lo que Android e iOS lanzan con el correo o la contraseña vacíos.
  * `invalid-email` pasa a `AUTH_INVALID_EMAIL` y `user-disabled` a `AUTH_USER_DISABLED`.
  * `too-many-requests` pasa a `AUTH_TOO_MANY_REQUESTS` y `network-request-failed` a `NETWORK_ERROR`.
  * Cualquier otro pasa a `AUTH_FAILED`, con el mensaje genérico.
* **Motivo:** la regla de negocio 8 pide traducir los errores a estados de interfaz. El mensaje de Firebase llega en inglés y cambia entre plataformas, así que la pantalla de login no puede mostrarlo tal cual.
* **Pendiente de confirmar:** estos códigos existen solo en la app y no están en el catálogo del backend (`backend/app/core/errors.py`) ni en el contrato de la empresa. Si el equipo los acepta, conviene documentarlos junto al catálogo.
* **Verificación:** el grupo "errores de Firebase Auth" de `test/api_client_auth_test.dart`.
