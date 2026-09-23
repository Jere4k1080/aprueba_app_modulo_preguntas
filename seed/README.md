# Esquemas de colecciones Firestore — Datos semilla

Referencia de esquemas para el script de seed del backend (`npm run seed`).
Los ids usados en los ejemplos son los que el frontend espera.
Los datos viven en `backend/src/seed/data.js`.

---

## Colección `tests` (Raíz)

Cinco documentos, uno por prueba PAES. El id del documento **es** el código de la
prueba.

```jsonc
// tests/lectora
{
  "id": "lectora",
  "label": "Comp. Lectora",
  "color": "#1A365D",
  "hasQuestions": true
}
```

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id` | `string` | ✔ | Código de la prueba: `lectora`, `m1`, `m2`, `cien`, `hist` |
| `label` | `string` | ✔ | Nombre legible para la UI |
| `color` | `string` | ✔ | Color hex de la prueba |
| `hasQuestions` | `boolean` | ✔ | `true` si hay banco de preguntas |

Documentos semilla:

| id | label | color |
|---|---|---|
| `lectora` | Comp. Lectora | `#1A365D` |
| `m1` | Matemática M1 | `#10B981` |
| `m2` | Matemática M2 | `#6366F1` |
| `cien` | Ciencias | `#F5B041` |
| `hist` | Historia y C. Soc. | `#EF4444` |

---

## Colección `skills` (Raíz)

Habilidad dentro de una prueba. El id es un slug generado.

```jsonc
// skills/sk_lectora_comp_lit
{
  "id": "sk_lectora_comp_lit",
  "name": "Comprensión de textos literarios",
  "testId": "lectora",
  "domain": "Comprensión lectora",
  "level": 2,
  "maxLevel": 4,
  "prerequisiteIds": ["sk_demo_lectora_localizar"],
  "status": "active",
  "resources": [
    {
      "type": "pdf",
      "title": "Temario y modelos de prueba oficiales de Competencia Lectora",
      "url": "https://demre.cl/",
      "source": "DEMRE"
    }
  ],
  "isDemo": true
}
```

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id` | `string` | ✔ | Identificador único |
| `name` | `string` | ✔ | Nombre de la habilidad |
| `testId` | `string` | ✔ | FK a `tests` |
| `domain` | `string` | ✔ | Dominio al que pertenece |
| `level` | `int` | ✔ | Nivel actual (1–4) |
| `maxLevel` | `int` | ✔ | Nivel máximo |
| `prerequisiteIds` | `string[]` | ✔ | IDs de habilidades prerequisito |
| `status` | `string` | ✔ | `done` \| `active` \| `locked` |
| `resources` | `SkillResource[]` | ✔ | Material de apoyo |
| `isDemo` | `boolean?` | | `true` en las habilidades de demostración del seed |

**`SkillResource`** (objeto embebido):

| Campo | Tipo | Requerido |
|---|---|---|
| `type` | `string` | ✔ (`video` \| `pdf` \| `exercise`) |
| `title` | `string` | ✔ |
| `url` | `string?` | |
| `duration` | `string?` | |
| `source` | `string?` | |

El seed carga 20 habilidades de demostración, cuatro por prueba, con prerrequisitos
dentro del árbol y recursos de DEMRE, Khan Academy, Memoria Chilena, la BCN o el INE.
Las nuevas usan IDs `sk_demo_<prueba>_<tema>`; `sk_lectora_comp_lit` conserva el suyo.

---

## Colección `questions` (Raíz)

Pregunta del banco. El id es un slug generado.
**Regla de integridad:** `correctAnswer` vive en la base de datos, pero el servicio
backend lo proyecta y lo omite en `GET /practice/next` y `GET /questions/{id}`.

```jsonc
// questions/q_lectora_001
{
  "id": "q_lectora_001",
  "testId": "lectora",
  "axis": "Comprensión lectora",
  "skillId": "sk_lectora_comp_lit",
  "difficulty": "d2",
  "statement": "Lee el fragmento y responde.\n\n> Cuando llegó la fábrica de cemento... \n\n¿Cuál es la idea principal del fragmento?",
  "options": [
    "La modernización de la industria",
    "El impacto ambiental del progreso",
    "La vida cotidiana en el campo",
    "Los avances tecnológicos del siglo XX"
  ],
  "correctAnswer": "B",
  "explanation": "1. El fragmento parte con la llegada de la fábrica...\nVerificación: ...",
  "cohortSpeedThresholds": {
    "p25": 15000,
    "p50": 25000,
    "p75": 45000,
    "p90": 60000
  },
  "status": "active"
}
```

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `id` | `string` | ✔ | Identificador único |
| `testId` | `string` | ✔ | FK a `tests` |
| `axis` | `string?` | | Eje temático |
| `skillId` | `string?` | | FK a `skills` |
| `difficulty` | `string` | ✔ | `d1` \| `d2` \| `d3` \| `d4` |
| `statement` | `string` | ✔ | Enunciado |
| `options` | `string[]` | ✔ | Alternativas A–D/E |
| `correctAnswer` | `string` | ✔ | Letra correcta (solo backend/admin) |
| `explanation` | `string?` | | Explicación corta |
| `cohortSpeedThresholds` | `map?` | | Umbrales precalculados en ms (`p25`, `p50`, `p75`, `p90`) |
| `status` | `string` | ✔ | `active` \| `draft` \| `disabled` |
| `isDemo` | `boolean?` | | `true` en las preguntas de demostración del seed |

El seed carga 20 preguntas de demostración, una por cada combinación de prueba y
dificultad. Las escribió el equipo; no vienen del banco de la empresa. Las nuevas usan
IDs `q_demo_<prueba>_<dificultad>`, por ejemplo `q_demo_m1_d3`. `q_lectora_001` conserva
su ID porque la respuesta, la recorrección y el estado de práctica de `usr_demo` la
referencian. La explicación va en texto, con pasos numerados y una línea final de
verificación.

---

## Colección `answers` (Raíz)

Respuesta del alumno a una pregunta. La API la crea tras evaluar la alternativa; el cliente no escribe en Firestore.
**Diseño:** Colección raíz para permitir agregación por `questionId` entre todos los alumnos
al calcular el percentil de cohorte (`cohortPercentile`).

```jsonc
// answers/ans_001
{
  "id": "ans_001",
  "userId": "usr_demo",
  "questionId": "q_lectora_001",
  "selected": "B",
  "correct": true,
  "elapsedMs": 42000,
  "cohortPercentile": 78,
  "answeredAt": "2026-09-15T14:30:00.000Z"
}
```

| Campo | Tipo | Requerido |
|---|---|---|
| `id` | `string` | ✔ |
| `userId` | `string` | ✔ |
| `questionId` | `string` | ✔ |
| `selected` | `string` | ✔ (letra A–E) |
| `correct` | `boolean` | ✔ |
| `elapsedMs` | `int` | ✔ |
| `cohortPercentile` | `int?` | |
| `answeredAt` | `timestamp` | ✔ |

---

## Colección `corrections` (Raíz)

Solicitud de recorrección de una pregunta. El cliente la envía a la API, que la crea en Firestore.
**Diseño:** Colección raíz para permitir a administración listar todas las solicitudes pendientes
sin importar el usuario.

```jsonc
// corrections/cor_001
{
  "id": "cor_001",
  "userId": "usr_demo",
  "questionId": "q_lectora_001",
  "reason": "wrong_answer",
  "comment": "La alternativa correcta debería ser C",
  "status": "pending",
  "potentialReward": { "amount": 250 },
  "createdAt": "2026-09-15T14:35:00.000Z",
  "reviewedAt": null,
  "reviewedBy": null
}
```

| Campo | Tipo | Requerido |
|---|---|---|
| `id` | `string` | ✔ |
| `userId` | `string` | ✔ |
| `questionId` | `string` | ✔ |
| `reason` | `string` | ✔ (`wrong_answer` \| `ambiguous` \| `typo` \| `bad_explanation` \| `other`) |
| `comment` | `string?` | |
| `status` | `string` | ✔ (`pending` \| `confirmed` \| `rejected`) |
| `potentialReward` | `object?` | `{ "amount": 250 }` |
| `rewardGranted` | `object?` | `{ "amount": 250 }` (tras confirmación) |
| `createdAt` | `timestamp` | ✔ |
| `reviewedAt` | `timestamp?` | |
| `reviewedBy` | `string?` | |

---

## Subcolección `users/{uid}/medalLedger`

Registro de movimientos de medallas de cada usuario. Solo el backend escribe.

```jsonc
// users/usr_demo/medalLedger/ml_001
{
  "id": "ml_001",
  "type": "answer_correct",
  "tier": "bronze",
  "amount": 1,
  "referenceId": "q_lectora_001",
  "createdAt": "2026-09-15T14:30:01.000Z"
}
```

| Campo | Tipo | Requerido |
|---|---|---|
| `id` | `string` | ✔ |
| `type` | `string` | ✔ (`answer_correct` \| `correction_confirmed` \| `exchange` \| `gift`) |
| `tier` | `string` | ✔ (`bronze` \| `silver` \| `gold` \| `diamond` \| `platinum`) |
| `amount` | `int` | ✔ (positivo = ganó, negativo = gastó) |
| `referenceId` | `string?` | |
| `createdAt` | `timestamp` | ✔ |

---

## Documento `users/{uid}/state/practice`

Estado de sesión y preguntas respondidas por el alumno. Usado por `GET /practice/next` para filtrar preguntas ya contestadas sin necesidad de escanear la colección `answers`.

```jsonc
// users/usr_demo/state/practice
{
  "answeredQuestionIds": [
    "q_lectora_001"
  ],
  "lastQuestionId": "q_lectora_001",
  "lastAnsweredAt": "2026-09-15T14:30:00.000Z",
  "activeSessionId": "sess_demo_01"
}
```

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `answeredQuestionIds` | `string[]` | ✔ | IDs de preguntas ya respondidas |
| `lastQuestionId` | `string?` | | Última pregunta entregada |
| `lastAnsweredAt` | `timestamp?` | | Fecha de última respuesta |
| `activeSessionId` | `string?` | | ID de la sesión actual |

El seed crea este documento para dos usuarios. `usr_demo` tiene respondida
`q_lectora_001`, así que le quedan 19 preguntas. `usr_demo_nuevo` tiene
`answeredQuestionIds` vacío y sirve para mostrar el flujo desde cero. Ninguno tiene
documento `users/{uid}`: el diccionario de datos todavía no define ese documento ni
dónde se guardan la cuota y las preferencias.

