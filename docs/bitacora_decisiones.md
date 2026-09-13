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
* **Decisión final:** Los esquemas de Firestore se documentan exclusivamente en [`seed/README.md`](file:///f:/Descargas%20Chrome/aprueba_app-20260903T024027Z-1-001/aprueba_app_modulo_preguntas/seed/README.md) para el backend en Node.js. En el cliente Flutter solo viven los modelos de contrato de la API (`Question`, `Correction`, `QuotaState`, etc.).

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
* **Decisión final:** En [`models.dart`](file:///f:/Descargas%20Chrome/aprueba_app-20260903T024027Z-1-001/aprueba_app_modulo_preguntas/lib/data/models/models.dart), `Correction.fromJson` exige estrictamente el formato `{amount: int}` tanto para `rewardGranted` como para `potentialReward`. Si el backend no envía el formato acordado, se reporta como defecto del servicio.

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
* **Decisión final:** En [`firestore.indexes.json`](file:///f:/Descargas%20Chrome/aprueba_app-20260903T024027Z-1-001/aprueba_app_modulo_preguntas/firestore.indexes.json) se dejaron únicamente los 4 índices que respaldan consultas operativas del módulo:
  1. `questions` (`testId ASC`, `difficulty ASC`)
  2. `questions` (`testId ASC`, `status ASC`, `difficulty ASC`)
  3. `answers` (`questionId ASC`, `answeredAt DESC`) — Cálculo de percentil de cohorte
  4. `corrections` (`userId ASC`, `createdAt DESC`) — Historial de reportes del estudiante

---

### ADR-08: Tratamiento de avisos del analizador estático (flutter analyze)

* **Estado:** **APROBADA**
* **Decisión:** Se corrigieron las 5 advertencias (`warning`) que causaban la salida con código de error de `flutter analyze` (variables locales no usadas, import innecesario y aserción no nula redundante). Se decidió de forma explícita **no modificar** los 38 avisos informativos (`info`) relativos a la deprecación de `withOpacity` en el código base heredado del cliente móvil.
* **Fundamento:** La regla de calidad del equipo estipula que `flutter analyze` debe correr sin advertencias. Los avisos de `withOpacity` pertenecen al código base completo del cliente (onboarding, tutores, suscripciones) que está fuera del alcance de la HU-20. Reemplazar `.withOpacity()` por `.withValues()` a lo largo de decenas de archivos ensuciaría el diff del repositorio con cambios cosméticos sin aportar valor al módulo de práctica.

