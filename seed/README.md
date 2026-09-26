# Datos semilla de Firestore

El seed carga en Firestore un banco de demostración y los documentos de las dos cuentas de prueba. Se corre desde `backend/` con `.venv/bin/python -m app.seed` (en Windows, `.venv/Scripts/python.exe -m app.seed`), con el emulador de Firestore activo o con `SEED_ALLOW_REMOTE=true` (ADR-22). Necesita además `SEED_DEMO_UID` y `SEED_DEMO_NEW_UID`, los UID de Firebase Authentication de `aprueba@demo.cl` y `aprueba2@demo.cl`. Si falta uno, o si no da un ID `usr_` que acepte la administración, el seed termina con código 1 antes de abrir Firestore (ADR-58).

Los datos están en `backend/app/seed/data/`: `tests.json`, `skills.json`, `questions.json`, `plans.json`, `features.json`, `users.json`, `answers.json` y `corrections.json`. `build_documents()`, en `backend/app/seed/__init__.py`, calcula lo que depende de otros documentos: `nameLower`, `emailLower`, `medalWallet`, `badgesTotal`, `quota`, `stats`, `flagCount`, `approvedStock`, `statementPreview`, `skillMastery` y `state/practice`. Todo se escribe en un solo lote, así que se carga completo o no se carga nada. Las fechas las pone el servidor de Firestore con `SERVER_TIMESTAMP` (ADR-14). Los IDs son fijos y otra corrida reescribe los mismos documentos.

Los campos de cada colección están definidos en [`docs/diccionario_de_datos.md`](../docs/diccionario_de_datos.md). Este archivo muestra lo que carga el seed, con ejemplos sacados de `build_documents()`. En las rutas, `<UID>` es el UID de la cuenta y `<hora del servidor>` es el valor de `SERVER_TIMESTAMP`.

---

## Qué carga

| Ruta | Documentos | Contenido |
|---|---:|---|
| `plans` | 3 | `free`, `uni` y `all`, con los valores de ejemplo de la administración salvo el `qDay` de `free` (ADR-64) |
| `features` | 1 | `f2`, la funcionalidad `mock_mode` que decide el modo facsímil (ADR-70) |
| `tests` | 5 | Las pruebas PAES, con 4 preguntas aprobadas cada una |
| `skills` | 20 | Cuatro habilidades por prueba |
| `questions` | 20 | Una por cada combinación de prueba y dificultad |
| `users` | 2 | `usr_<UID>` de `aprueba@demo.cl` y de `aprueba2@demo.cl` |
| `users/{id}/answers` | 5 | Respuestas de `aprueba@demo.cl` |
| `users/{id}/skillMastery` | 5 | Dominio de `aprueba@demo.cl` en las habilidades que respondió |
| `users/{id}/state/practice` | 2 | Uno por cuenta |
| `medalTransactions` | 4 | Una por cada respuesta correcta |
| `corrections` | 1 | Solicitud pendiente de `aprueba@demo.cl` |

En total son 68 documentos.

`aprueba@demo.cl` eligió las cinco pruebas y respondió una pregunta de `lectora` en d1, otra en d2, y una de `m1`, `m2` y `hist`. Acertó cuatro, así que tiene 4 bronces, 4 movimientos en `medalTransactions` y 5 de 10 preguntas usadas hoy. La respuesta incorrecta, de `m2` en d2, tiene una solicitud de recorrección pendiente. Le quedan 15 preguntas.

`aprueba2@demo.cl` eligió `lectora` y `m1`, no tiene respuestas ni medallas y parte con 0 de 10. Le quedan las 8 preguntas de esas dos pruebas.

Las dos cuentas están en el plan `free`, con `state` `active` y un límite de 10, la base de la regla de negocio 1. El ejemplo de la administración trae 20 para `free`, y eso va en la consulta a Max (ADR-64).

---

## `plans`

```jsonc
// plans/free
{
  "name": { "es": "Gratis", "en": "Free" },
  "nameLower": "gratis",
  "price": 0,
  "currency": "USD",
  "color": "#64748B",
  "features": ["f3"],
  "limits": { "qDay": 10, "groups": 1, "tests": 1 },
  "badges": { "login": 1, "purchase": 0, "correct": 1 },
  "stripeProductId": null,
  "stripePriceId": null,
  "system": true,
  "createdAt": "<hora del servidor>",
  "updatedAt": "<hora del servidor>"
}
```

`uni` tiene `qDay` 0 y `badges` `{login: 1, purchase: 5, correct: 1}`. `all` tiene `qDay` 0 y `badges` `{login: 2, purchase: 10, correct: 2}`. Los nombres en español son los de la administración, y los nombres en inglés son supuesto (ADR-69). Solo `all` incluye `f2`, así que es el único plan con modo facsímil (ADR-70).

---

## `features`

```jsonc
// features/f2
{
  "key": "mock_mode",
  "icon": "📝",
  "name": { "es": "Modo facsímil (ensayos)", "en": "Mock exam mode" },
  "order": 2
}
```

Es la única funcionalidad del catálogo de la consola que lee el módulo (ADR-70). El resto del catálogo lo administra la consola en el proyecto de la empresa. El nombre en inglés es supuesto.

---

## `tests`

```jsonc
// tests/lectora
{
  "label": "Comp. Lectora",
  "nameLower": "comp. lectora",
  "color": "#1A365D",
  "axes": ["Localizar", "Comprensión lectora", "Interpretar", "Evaluar"],
  "order": 1,
  "active": true,
  "countryId": "cl",
  "examId": "cl_paes",
  "approvedStock": 4
}
```

| ID | `label` | `color` | `order` |
|---|---|---|---:|
| `lectora` | Comp. Lectora | `#1A365D` | 1 |
| `m1` | Matemática M1 | `#10B981` | 2 |
| `m2` | Matemática M2 | `#6366F1` | 3 |
| `cien` | Ciencias | `#F5B041` | 4 |
| `hist` | Historia y C. Soc. | `#EF4444` | 5 |

`axes` sale de los ejes de las habilidades de cada prueba.

---

## `skills`

```jsonc
// skills/sk_lectora_comp_lit
{
  "testId": "lectora",
  "name": "Comprensión de textos literarios",
  "axis": "Comprensión lectora",
  "level": 2,
  "maxLevel": 4,
  "prerequisites": ["sk_demo_lectora_localizar"],
  "resources": [
    {
      "type": "pdf",
      "title": "Temario y modelos de prueba oficiales de Competencia Lectora",
      "url": "https://demre.cl/",
      "source": "DEMRE"
    }
  ],
  "createdAt": "<hora del servidor>",
  "updatedAt": "<hora del servidor>"
}
```

Son 20 habilidades, cuatro por prueba, con prerrequisitos dentro del árbol y recursos de DEMRE, Khan Academy, Memoria Chilena, la BCN o el INE. Usan IDs `sk_demo_<prueba>_<tema>`, salvo `sk_lectora_comp_lit`, que viene de la primera versión del seed. Como el modelo de junio no da a `skills` un campo de origen, las de demostración son las de `skills.json` (ADR-69).

---

## `questions`

```jsonc
// questions/qst_080b7064ec
{
  "testId": "lectora",
  "axis": "Comprensión lectora",
  "skillId": "sk_lectora_comp_lit",
  "difficulty": "d2",
  "statement": "Lee el fragmento y responde.\n\n> Cuando llegó la fábrica de cemento, ...\n\n¿Cuál es la idea principal del fragmento?",
  "options": [
    "La modernización de la industria",
    "El impacto ambiental del progreso",
    "La vida cotidiana en el campo",
    "Los avances tecnológicos del siglo XX"
  ],
  "correctAnswer": "B",
  "explanation": "1. El fragmento parte con la llegada de la fábrica...\nVerificación: ...",
  "requiredSkillText": "Comprensión de textos literarios",
  "status": "published",
  "reviewStatus": "approved",
  "flagCount": 0,
  "randomKey": 0.257537,
  "stats": {
    "timesAnswered": 1,
    "timesCorrect": 1,
    "sumElapsedMs": 38000,
    "elapsedBuckets": {
      "lt10": 0, "lt20": 0, "lt30": 0, "lt45": 1, "lt60": 0,
      "lt90": 0, "lt120": 0, "lt180": 0, "lt300": 0, "gte300": 0
    }
  },
  "source": "seed_demo",
  "countryId": "cl",
  "examId": "cl_paes",
  "origin": "manual",
  "version": 1,
  "createdAt": "<hora del servidor>",
  "updatedAt": "<hora del servidor>"
}
```

Las 20 preguntas las escribió el equipo y no vienen del banco de la empresa. `source: "seed_demo"` las separa de las reales (ADR-69). La explicación va en texto, con pasos numerados y una línea final de verificación. `stats` y `flagCount` ya cuentan las respuestas y la solicitud de recorrección del seed.

El ID es `qst_` más los primeros 10 hexadecimales del SHA-1 del ID anterior, así que la equivalencia se puede recalcular (ADR-62):

| ID anterior | ID nuevo | ID anterior | ID nuevo |
|---|---|---|---|
| `q_demo_lectora_d1` | `qst_da7712782b` | `q_demo_m2_d3` | `qst_89abee2144` |
| `q_lectora_001` | `qst_080b7064ec` | `q_demo_m2_d4` | `qst_5b6a511857` |
| `q_demo_lectora_d3` | `qst_ffc9d70c58` | `q_demo_cien_d1` | `qst_89ec0bd93e` |
| `q_demo_lectora_d4` | `qst_b55f58c63f` | `q_demo_cien_d2` | `qst_50a86416a9` |
| `q_demo_m1_d1` | `qst_9873643c47` | `q_demo_cien_d3` | `qst_1101a72d7c` |
| `q_demo_m1_d2` | `qst_84a0b1e1d1` | `q_demo_cien_d4` | `qst_6fa24d8150` |
| `q_demo_m1_d3` | `qst_d627ef81f3` | `q_demo_hist_d1` | `qst_8995758927` |
| `q_demo_m1_d4` | `qst_b72993bcce` | `q_demo_hist_d2` | `qst_f2babea270` |
| `q_demo_m2_d1` | `qst_17392f3fb1` | `q_demo_hist_d3` | `qst_a61c41a428` |
| `q_demo_m2_d2` | `qst_4574d5002b` | `q_demo_hist_d4` | `qst_989222c2fc` |

---

## `users`

```jsonc
// users/usr_<UID> de aprueba@demo.cl
{
  "name": "Estudiante Demo",
  "nameLower": "estudiante demo",
  "email": "aprueba@demo.cl",
  "emailLower": "aprueba@demo.cl",
  "authProvider": "password",
  "locale": "es",
  "country": "CL",
  "plan": "free",
  "state": "active",
  "subscriptionId": null,
  "school": null,
  "region": null,
  "age": null,
  "streak": 1,
  "medalWallet": { "bronze": 4, "silver": 0, "gold": 0, "diamond": 0, "platinum": 0 },
  "badgesTotal": 4,
  "selectedTests": ["lectora", "m1", "m2", "cien", "hist"],
  "practiceFormat": "random",
  "difficulty": "d1",
  "quota": {
    "used": 5,
    "max": 10,
    "date": "2026-09-25",
    "bonusSchool": false,
    "bonusAddress": false,
    "unlimited": false
  },
  "avatarColor": "#1A365D",
  "theme": "light",
  "planStatus": "none",
  "dailyReminder": false,
  "createdAt": "<hora del servidor>",
  "updatedAt": "<hora del servidor>",
  "lastActivityAt": "<hora del servidor>"
}
```

`quota.date` es el día en que corre el seed, en el huso de `QUOTA_RESET_TIMEZONE`. `aprueba2@demo.cl` tiene la misma forma, con `name` "Estudiante Nuevo", `streak` 0, `selectedTests` `["lectora", "m1"]`, la billetera en cero y `quota.used` 0.

---

## `users/{id}/answers`

```jsonc
// users/usr_<UID>/answers/ans_da7712782b
{
  "questionId": "qst_da7712782b",
  "testId": "lectora",
  "axis": "Localizar",
  "skillId": "sk_demo_lectora_localizar",
  "selected": "C",
  "correct": true,
  "elapsedMs": 24000,
  "cohortPercentile": 50,
  "difficulty": "d1",
  "answeredAt": "<hora del servidor>"
}
```

El ID es `ans_` más los 10 hexadecimales de la pregunta. `cohortPercentile` vale 50 porque cada respuesta del seed es la primera de su pregunta (ADR-63).

---

## `users/{id}/skillMastery`

```jsonc
// users/usr_<UID>/skillMastery/sk_demo_lectora_localizar
{
  "testId": "lectora",
  "correct": 1,
  "total": 1,
  "percent": 100,
  "level": 1,
  "status": "in_progress",
  "updatedAt": "<hora del servidor>"
}
```

En el seed, `level` es el número de aciertos con tope en `maxLevel` (ADR-69).

---

## `users/{id}/state/practice`

```jsonc
// users/usr_<UID>/state/practice
{
  "answeredQuestionIds": [
    "qst_da7712782b",
    "qst_080b7064ec",
    "qst_9873643c47",
    "qst_4574d5002b",
    "qst_8995758927"
  ],
  "lastQuestionId": "qst_8995758927",
  "lastAnsweredAt": "<hora del servidor>"
}
```

El de `aprueba2@demo.cl` solo tiene `answeredQuestionIds` vacío.

---

## `medalTransactions`

```jsonc
// medalTransactions/mtx_286ccb1fe2
{
  "userId": "usr_<UID>",
  "tier": "bronze",
  "amount": 1,
  "reason": "answer_correct",
  "refId": "qst_da7712782b",
  "at": "<hora del servidor>"
}
```

`amount` sale de `plans/free.badges.correct`. El ID es `mtx_` más 10 hexadecimales del SHA-1 de un texto fijo con el motivo, la cuenta y la pregunta, para que no cambie entre corridas.

---

## `corrections`

```jsonc
// corrections/cor_21ef180d4a
{
  "userId": "usr_<UID>",
  "userName": "Estudiante Demo",
  "questionId": "qst_4574d5002b",
  "testId": "m2",
  "axis": "Álgebra y funciones",
  "difficulty": "d2",
  "statementPreview": "¿Cuáles son las soluciones de la ecuación x² − 5x + 6 = 0?",
  "reason": "Creo que la alternativa C también es correcta.",
  "reasonCode": "wrong_answer",
  "comment": "Creo que la alternativa C también es correcta.",
  "proposedAnswer": "C",
  "state": "pending",
  "createdAt": "<hora del servidor>",
  "resolvedAt": null,
  "resolvedBy": null,
  "note": null,
  "rewardGranted": null
}
```

Tiene todos los campos que lee `GET /admin/corrections` (ADR-61). `reasonCode` y `comment` siguen la propuesta de ADR-67.

---

## Datos del seed anterior

El seed del 2026-09-23 dejó en el proyecto `aprueba-app-modulo-preguntas` documentos que el nuevo no reescribe: las 20 preguntas con los IDs anteriores de la tabla de `questions`, `users/usr_demo` con `medalLedger/ml_001` y `state/practice`, `users/usr_demo_nuevo` con `state/practice`, `answers/ans_001` y `corrections/cor_001`. Firestore no borra las subcolecciones al borrar un documento, así que hay que borrarlas una por una. `tests` y `skills` usan los mismos IDs y el seed nuevo los reemplaza completos. El borrado se hace después de fusionar y con confirmación del equipo.
