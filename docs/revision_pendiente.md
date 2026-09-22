# Revisión pendiente — fusión sin revisión cruzada del 2026-09-13

Este documento existe porque los ocho pull requests abiertos ese día se fusionaron (los que pudieron) sin que otro integrante del equipo los revisara, por ausencia del equipo esa semana. Ver ADR-16 en `docs/bitacora_decisiones.md`. De los ocho, #7, #1 y #4 se fusionaron el 2026-09-22 con la aprobación de Sebastián y Martín, dada por WhatsApp; los otros cinco siguen sin una segunda lectura. Ese día se sumó el PR #10, fusionado sin revisión (sección al final). Esta guía es para que Sebastián y Martín puedan hacer esa revisión durante la semana, sin tener que reconstruir el contexto desde cero.

Prioridad de lectura sugerida: primero el bloque de Drift e integridad (Sebastián lo va a necesitar para la Iteración 3), después el backend (envelope, catálogo de errores, ADR-09 a ADR-12). El PR #10 es corto y se puede leer en cualquier momento. #7, #1 y #4 ya tienen aprobación, pero las preguntas de sus secciones no tienen respuesta en este documento; si en WhatsApp se respondió alguna, conviene copiarla aquí.

---

## PR #6 — limpieza del working tree de main

**Estado:** fusionado a `main`, sin revisión cruzada.

**Archivos:** `docs/bitacora_decisiones.md` (agrega ADR-15).

**Qué mirar con atención:** esta rama no toca código, solo documenta un hallazgo de auditoría (que `main` tenía 11 archivos modificados sin commitear que replicaban el contenido de las cuatro ramas originales, aplicados a mano). El trabajo real de "limpieza" fue un `git stash`, no un commit — el stash sigue en el repositorio local desde donde se hizo (`stash@{0}`, mensaje "audit: estado manual pre-mezcla de las 4 ramas..."). Si nadie más tiene ese stash localmente, se puede recrear el contenido íntegro leyendo el ADR-15, porque documenta exactamente qué había y contra qué rama se verificó cada archivo.

**Preguntas que debería poder responder quien revise:**
- ¿Alguien sabe quién aplicó ese contenido a mano sobre `main` y por qué, en vez de esperar los PR? Esto no quedó resuelto, solo documentado.
- ¿El stash local sigue existiendo en algún checkout del equipo, o se perdió?

---

## PR #8 — graphify-out/ en .gitignore

**Estado:** fusionado a `main`, sin revisión cruzada.

**Archivos:** `.gitignore` (4 líneas agregadas).

**Qué mirar con atención:** cambio de una línea, bajo riesgo. Verificado en su momento con `git check-ignore` que la regla efectivamente excluye `graphify-out/`.

**Preguntas:** ninguna crítica. Solo confirmar que nadie tenía `graphify-out/` ya trackeado en su copia local (si alguien lo commiteó antes de esta regla, `.gitignore` no lo va a destrackear solo).

---

## PR #3 — README oficial del equipo

**Estado:** fusionado a `main`, sin revisión cruzada.

**Archivos:** `README.md` (reemplazo casi completo).

**Qué mirar con atención:** que la sección de despliegue en Vercel siga siendo operativa (URLs, variables de entorno) y que los datos del equipo, roles y metodología XP sean correctos y estén actualizados. Este PR no tiene verificación automática asociada (no toca código), así que la única revisión posible es lectura humana del contenido.

**Preguntas:**
- ¿Los roles y el alcance descritos coinciden con lo que el equipo está haciendo hoy, o quedaron desactualizados por los cambios de esta misma tanda de PR?
- ¿La URL de Vercel que aparece en el README sigue siendo la correcta? (Hay un pendiente conocido de que el dominio de producción responde 404 y pide iniciar sesión — si ese pendiente sigue abierto, vale la pena una nota en el README o en la bitácora).

---

## PR #2 — updateQuestionAnswer y pruebas de integridad de Drift

**Estado:** fusionado a `main`, sin revisión cruzada. **Este es el que Sebastián necesita revisar con más cuidado antes de la Iteración 3**, porque toca directamente la caché que él mantiene.

**Archivos:** `lib/data/local/database.dart`, `lib/data/repositories/practice_repository.dart`, `test/drift_integrity_test.dart` (nuevo).

**Qué mirar con atención:**
- `updateQuestionAnswer(id, correctAnswer, [shortExplanation])` en `database.dart` es la única función que puede escribir `correctAnswer` en la tabla `CachedQuestions`. Confirmar que sigue siendo así después de cualquier cambio futuro — si en algún momento aparece otra escritura a esa columna que no sea esta función, la regla de integridad se rompe en silencio.
- En `PracticeRepository.answer()`, la llamada a `_db.updateQuestionAnswer()` ocurre **después** de recibir la respuesta de `POST /questions/:id/answer`, nunca antes. Es el único call site.
- `_cacheQuestion()` (el método que cachea la pregunta al pedir `next()` o `question(id)`) deliberadamente no incluye `correctAnswer` en el `CachedQuestionsCompanion` que construye — por eso la columna queda en su default (`NULL`). Si alguien "simplifica" ese método para pasar el objeto `Question` completo en vez de campo por campo, `correctAnswer` se colaría sin querer.
- Las 3 pruebas de `drift_integrity_test.dart` usan una base de datos Drift en memoria y un interceptor de Dio con payloads canónicos, no mocks de la capa de datos. Es un patrón bueno para replicar en pruebas futuras de este módulo.

**Preguntas que debería poder responder Sebastián:**
- ¿`updateQuestionAnswer` necesita algún día borrar o invalidar la caché si el backend corrige una pregunta (recorrección confirmada)? Hoy no hay ningún mecanismo para eso — la caché local queda con la respuesta que se guardó la primera vez.
- ¿El nombre `shortExplanation` en Drift coincide exactamente con el campo que va a devolver el backend en `POST /answer` una vez que ese endpoint se implemente en la Iteración 3? Hoy es una promesa entre el modelo Dart (`AnswerResult.shortExplanation`) y un backend que todavía no existe.

---

## PR #5 — status HTTP de FORMAT_REQUIRES_PLAN (fusionado a feature/backend-scaffold y, con el PR #4, a main)

**Estado:** fusionado a `feature/backend-scaffold` sin revisión cruzada. Llegó a `main` el 2026-09-22 dentro del PR #4, que sí tuvo aprobación.

**Archivos:** `backend/src/errors/catalog.js` (1 línea), `docs/bitacora_decisiones.md` (ADR-13).

**Qué mirar con atención:** el cambio es de una sola línea (403 → 422), pero el motivo importa: `FORMAT_REQUIRES_PLAN` es un error de negocio (el alumno pidió un formato que su plan no cubre), no de autorización. Si el interceptor de Dio del cliente Flutter trata 401/403 como "cerrar sesión", este código con 403 lo habría mandado a cerrar sesión en vez de al muro de pago. El endpoint que dispara este error todavía no existe (Iteración 3), así que esto no se pudo probar en vivo — solo se verificó que el catálogo quedó consistente.

**Preguntas:**
- Cuando se implemente el endpoint que devuelve `FORMAT_REQUIRES_PLAN`, ¿el cliente lee `error.code` para abrir el muro de pago? Ese error responde 422 y `VALIDATION_ERROR` responde 400. El cliente debe distinguirlos por código, sin reducir ambos a un mensaje genérico.

---

## PR #7 — timestamps del seed (fusionado el 2026-09-22)

**Estado:** fusionado a `feature/backend-scaffold` el 2026-09-22, con la aprobación de Sebastián y Martín por WhatsApp. Antes estuvo bloqueado por un conflicto en `docs/bitacora_decisiones.md` con el PR #5.

**Archivos:** `backend/src/seed/seed.js`, `docs/bitacora_decisiones.md` (ADR-14).

**Naturaleza del conflicto:** ADR-13 (del PR #5, ya fusionado en `backend-scaffold`) y ADR-14 (de este PR) se insertan en el mismo punto del archivo — justo después de ADR-12 — porque ambas ramas se crearon desde el mismo commit base de `backend-scaffold`, antes de que cualquiera de las dos se fusionara. No es un desacuerdo de contenido: son dos decisiones distintas que simplemente compiten por el mismo lugar en el archivo. No se resolvió a la fuerza, como pidió el equipo.

**Cómo se desbloqueó:** se integró `feature/backend-scaffold` en esta rama con el commit `f0bce0f`, dejando ADR-13 antes de ADR-14 sin cambiar el texto de ninguno, y después se fusionó el PR.

**Qué mirar con atención en el contenido en sí (además del conflicto):** el cambio reemplaza `new Date().toISOString()` por `admin.firestore.Timestamp.now()` en 4 campos (`answeredAt`, dos `createdAt`, `lastAnsweredAt`). No se pudo ejecutar el seed contra un emulador real porque `firebase-tools` no estaba instalado en el entorno donde se hizo el cambio — se verificó solo sintaxis y `require()` limpio.

**Preguntas:**
- ¿Alguien ha corrido `npm run seed` contra el emulador real con este cambio aplicado? Sigue sin probarse en vivo.

---

## PR #1 — 5 advertencias del analizador (fusionado el 2026-09-22)

**Estado:** fusionado a `main` el 2026-09-22, con la aprobación de Sebastián y Martín por WhatsApp. Antes estuvo bloqueado por el mismo tipo de conflicto que el PR #7, pero contra `main`.

**Archivos:** `docs/bitacora_decisiones.md` (ADR-08), `lib/data/repositories/profile_repository.dart`, `lib/data/services/phone_auth_service.dart`, `lib/features/groups/create_group_screen.dart`, `lib/features/medals/medals_screen.dart`, `lib/features/practice/question_screen.dart`.

**Naturaleza del conflicto:** ADR-15 (ya fusionado a `main` vía PR #6) y ADR-08 (de este PR) se insertan en el mismo punto — justo después de ADR-07 — por la misma razón que el PR #7: ambas ramas partieron del mismo commit base de `main` antes de que cualquiera de las dos se fusionara. De nuevo, no es contenido contradictorio, es competencia por el mismo lugar en el archivo.

**Cómo se desbloqueó:** se integró `main` en esta rama con el commit `b9bf462`, dejando ADR-08 antes de ADR-15 en orden numérico, y después se fusionó el PR.

**Qué mirar con atención además del conflicto — importante para el alcance del equipo:** este PR mezcla en un solo commit archivos dentro del módulo de práctica (`question_screen.dart`) con archivos fuera de alcance (`profile_repository.dart`, `phone_auth_service.dart`, `groups/create_group_screen.dart`, `medals/medals_screen.dart`). El criterio del equipo pide que las correcciones de advertencias fuera del módulo vayan en un commit separado para que el límite de alcance quede visible en el historial. Aquí no se hizo así — quedó todo en un solo commit. No se deshizo porque ya estaba hecho y separar el historial ahora generaría más riesgo que beneficio, pero vale la pena que quien revise lo sepa y lo tenga presente para la próxima vez.

**Preguntas:**
- ¿Alguien del equipo (Sebastián, ya que toca su capa de presentación) revisó que las correcciones fuera del módulo no cambiaron comportamiento, solo eliminaron código muerto? Se verificó por lectura de diff en la auditoría; la aprobación por WhatsApp no dice si se revisó este punto.

---

## PR #4 — andamiaje de backend (fusionado el 2026-09-22)

**Estado:** fusionado a `main` el 2026-09-22, con la aprobación de Sebastián y Martín por WhatsApp. Antes estuvo bloqueado porque la cadena de ADR que traía chocaba con ADR-15 en el mismo punto del archivo. Se integró `main` en la rama con el commit `c73a9ac`, dejando ADR-09 a ADR-14 antes de ADR-15.

**Archivos:** todo `backend/` (Express, Firebase Admin, envelope, catálogo de errores, auth JWT, `sanitizeQuestion()`, seed, health check), `docs/diccionario_de_datos.md` (nuevo), `docs/bitacora_decisiones.md` (ADR-09 a ADR-12, más ADR-08 ya resuelto con `fix-analyzer-warnings`, más ADR-13 del PR #5 ya fusionado en esta rama).

**Este es el que Martín y Sebastián necesitan revisar con más cuidado antes de la Iteración 3**, porque es el andamiaje completo sobre el que se van a construir los 13 servicios.

**Qué mirar con atención:**
- **Envelope (`backend/src/middleware/envelope.js` + `errorHandler.js`):** envuelve tanto respuestas exitosas (`res.sendData`) como errores (`res.sendError`), incluyendo errores no controlados y JSON inválido en el body. Verificado con `node test/health.test.js` (5/5 en verde) y con una ruta 404 real.
- **Auth (`backend/src/middleware/auth.js`):** valida firma y expiración del JWT (`jwt.verify`), no solo que el header exista. Cuando el token expira, devuelve `AUTH_TOKEN_EXPIRED` en vez de un genérico `AUTH_REQUIRED` — el cliente Flutter necesita distinguir estos dos códigos para decidir si intenta refrescar el token o cierra sesión directamente.
- **Firebase Admin (`backend/src/config/firebase.js`):** funciona con y sin emulador (usa `FIRESTORE_EMULATOR_HOST` si existe; si no, cae a Application Default Credentials, que es donde debe entrar `GOOGLE_APPLICATION_CREDENTIALS` en producción sin que el JSON se versione).
- **Riesgo de configuración sin resolver:** `backend/src/config/index.js` tiene `JWT_SECRET` con un valor por defecto público (el mismo que aparece en `backend/.env.example`) si la variable de entorno no está definida. El servidor arranca igual en producción sin ese secreto configurado, en vez de fallar. Esto no se corrigió en esta tanda — queda para quien revise decidir si es bloqueante antes de desplegar.
- **`sanitizeQuestion()` (`backend/src/services/questionService.js`):** elimina `correctAnswer` y `explanation` incondicionalmente. Hoy no hay ninguna ruta que emita preguntas todavía (los 13 servicios no están implementados), así que esta función nunca se ha ejercitado con una ruta real — cuando se implemente `GET /practice/next` en la Iteración 3, confirmar que ese endpoint pasa el documento por `sanitizeQuestion()` antes de responder. No hay ningún mecanismo automático que lo obligue.
- **Seed (`backend/src/seed/seed.js`):** usa IDs fijos con `.set()`, así que correrlo dos veces no duplica documentos, pero reescribe los timestamps. Estos son `Timestamp` de Firestore desde que entró el PR #7.
- **ADR-09 a ADR-12 siguen "PROPUESTA PARA RATIFICACIÓN":** ninguna de las cuatro se ha ratificado formalmente por el equipo todavía. Son:
  - ADR-09 (`answeredQuestionIds` como arreglo en `users/{uid}/state/practice`): el margen contra el límite de 1 MB de Firestore es cómodo (se estimó en años, no meses) con el ritmo de cuota gratuita, pero el cálculo no considera usuarios con plan de pago y cuota ilimitada — vale la pena que el equipo lo tenga presente al ratificar.
  - ADR-10 (umbrales de percentil precalculados en `questions`): depende de un proceso programado que **no existe todavía**. El equipo prevé construirlo en la Iteración 4.
  - ADR-11 (reinicio de cuota configurable por variables de entorno): sin código que lo consuma todavía, es solo la variable de entorno documentada.
  - ADR-12 (`sanitizeQuestion()` centralizado): esta ya está implementada y probada; las otras tres son solo diseño en papel.

**Preguntas que Martín y Sebastián deberían poder responder:**
- ¿El equipo ratifica ADR-09 a ADR-12 tal como están, o alguna necesita ajuste antes de construir los servicios de la Iteración 3 sobre ellas?
- ¿Quién es responsable de que `JWT_SECRET` tenga un valor real antes de cualquier despliegue con tráfico real, y hay algo que impida que el servidor arranque sin él?
- ¿El cliente Flutter (capa de Sebastián) ya está preparado para leer `error.code` del envelope y no solo el status HTTP, dado que varios códigos de negocio comparten status (422) con `VALIDATION_ERROR`?

---

## PR #10: índice de la bitácora y corrección de ADR-08 (fusionado sin revisión)

**Estado:** fusionado a `main` el 2026-09-22 sin revisión cruzada, por decisión explícita tomada durante la auditoría. Está registrado en ADR-16.

**Archivos:** `docs/bitacora_decisiones.md`, `docs/diccionario_de_datos.md`.

**Qué mirar con atención:** la corrección de ADR-08. El texto anterior atribuía los 38 avisos de `flutter analyze` a `withOpacity` en código del cliente fuera del alcance. Medidos con Flutter 3.44.7, 14 están en `lib/features/practice/`. La decisión de no tocarlos se mantuvo y cambió el fundamento. El resto del PR es mecánico: siete entradas nuevas en el índice y cinco enlaces `file:///` convertidos en rutas relativas.

**Preguntas:**
- ¿El equipo corrige los 14 avisos que están dentro del módulo o los deja como están?
- ¿Con qué versión de Flutter trabaja cada integrante? El recuento cambia con ella: el aviso de `value` deprecado aparece desde Flutter 3.33.
