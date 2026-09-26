# Backend del módulo de preguntas

API REST del módulo de práctica de Aprueba, escrita en Python 3.12 con FastAPI sobre Firestore. Reemplazó al backend Node y Express por decisión de la contraparte (ADR-30) y sigue las convenciones del backend de administración que especificó Max (ADR-31).

Por ahora la API solo expone `GET /api/v1/health`. Los trece servicios del módulo llegan en las iteraciones siguientes. `sanitize_question()` y `calculate_cohort_percentile()` ya están en `app/services/questions.py`, con sus pruebas, aunque ninguna ruta las usa todavía.

## Stack

Las versiones van fijas con `==`. La regla 4 de `CLAUDE.md` prohíbe subirlas para que algo compile.

| Paquete | Versión | Uso |
|---|---|---|
| `fastapi` | 0.141.1 | Framework HTTP, routers, dependencias y OpenAPI |
| `uvicorn[standard]` | 0.53.0 | Servidor ASGI en local y en la imagen de Cloud Run |
| `pydantic` | 2.13.5 | Modelos de entrada y salida |
| `pydantic-settings` | 2.15.0 | Configuración desde variables de entorno y `.env` |
| `google-cloud-firestore` | 2.31.0 | Cliente asíncrono `AsyncClient` |
| `google-auth` | 2.58.0 | Credenciales de la cuenta de servicio y credencial anónima de Firebase Admin en modo emulador |
| `firebase-admin` | 7.7.0 | Solo para verificar el ID token de Firebase Auth con `auth.verify_id_token` (ADR-40) |
| `starlette` | 1.7.0 | Base de FastAPI. Se fija porque `app/core/` la importa directo |
| `tzdata` | 2026.4 | Husos horarios para `zoneinfo`, que Windows no trae |

`requirements-dev.txt` agrega `pytest==9.1.1` y `httpx==0.28.1`, que usa el `TestClient`. `.python-version` fija 3.12 para uv y para Vercel.

## Estructura

```
backend/
├── app/
│   ├── main.py              create_app(): middlewares, CORS, manejadores de error y routers
│   ├── __main__.py          python -m app sirve la API en PORT
│   ├── core/
│   │   ├── config.py        Settings y controles de arranque
│   │   ├── envelope.py      ok(), created(), no_content(), meta() y RequestIdMiddleware
│   │   ├── errors.py        ApiError, catálogo es/en, manejadores de error, JsonBodyMiddleware y UnhandledErrorMiddleware
│   │   ├── i18n.py          idioma por Accept-Language
│   │   ├── deps.py          get_current_user y get_optional_user, que validan el token de Firebase, y los alias DB, CurrentUser y OptionalUser
│   │   └── pagination.py    encode_cursor(), decode_cursor(), PageParams y paginate()
│   ├── db/firestore.py      AsyncClient único, get_firebase_app() y nombres de colecciones (COL)
│   ├── routers/health.py    GET y HEAD /api/v1/health
│   ├── schemas/             CamelModel y modelos del health
│   ├── services/questions.py
│   └── seed/                python -m app.seed y el banco de demostración en data/*.json
├── tests/                   pytest
├── requirements.txt
├── requirements-dev.txt
├── Dockerfile               imagen para Cloud Run
├── vercel.json              preset FastAPI, región gru1
└── .env.example             nombres de variables, sin valores reales
```

## Entorno local

Con uv:

```bash
cd backend
uv venv --python 3.12 .venv
uv pip install --python .venv -r requirements-dev.txt
cp .env.example .env
```

Con pip:

```bash
cd backend
python3.12 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
cp .env.example .env
```

Los comandos de más abajo usan `.venv/bin/python`. En Windows es `.venv/Scripts/python.exe`.

## Emulador de Firestore

Se levanta desde la raíz del repositorio, en otra terminal:

```bash
npx --yes firebase-tools emulators:start --only firestore --project demo-aprueba
```

Queda en `127.0.0.1:8080`, que es el valor de `FIRESTORE_EMULATOR_HOST` en `.env.example`, y carga `firestore.rules`, el archivo de reglas que declara `firebase.json`. Necesita Node.js, solo para `npx`, y Java 21. Se levanta como `demo-aprueba`, el mismo ID que usa el backend para Firestore (`FIRESTORE_EMULATOR_PROJECT_ID`), así que la interfaz de `http://127.0.0.1:4000` muestra lo que carga el seed. El prefijo `demo-` hace que el emulador no busque un proyecto real. `FIREBASE_PROJECT_ID` va aparte, con el proyecto real, y solo sirve para validar tokens (ADR-49).

## Datos de prueba

```bash
.venv/bin/python -m app.seed
```

El seed lee los JSON de `app/seed/data/` y escribe `plans`, `features`, `tests`, `skills`, `questions`, `users`, `medalTransactions` y `corrections`, más las subcolecciones `answers`, `skillMastery` y `state/practice` de cada alumno. Necesita `SEED_DEMO_UID` y `SEED_DEMO_NEW_UID`, los UID de Firebase de `aprueba@demo.cl` y `aprueba2@demo.cl`, que están en la consola de Firebase, en Authentication. Con ellos crea `users/usr_<UID>` con `new_user()`, la misma función del alta (ADR-58 y ADR-66). Escribe todo en un solo lote y con IDs fijos, así que otra corrida reescribe los mismos documentos. Las fechas las pone el servidor de Firestore con `SERVER_TIMESTAMP` (ADR-14), y `quota.date` toma la fecha del día en `QUOTA_RESET_TIMEZONE`. Lo que carga, con ejemplos, está en [`seed/README.md`](../seed/README.md).

Sin `FIRESTORE_EMULATOR_HOST` el seed exige `SEED_ALLOW_REMOTE=true`. Si falta, termina con código 1 antes de abrir Firestore (ADR-22). Lo mismo pasa si falta un UID o si con el prefijo `usr_` no cabe en el patrón de la administración. Para el proyecto real se corre desde `backend/`, porque pydantic-settings lee el `.env` del directorio actual. `FIREBASE_SERVICE_ACCOUNT_BASE64` se define solo para esa ejecución, con la cuenta de servicio leída desde un JSON fuera del repositorio.

## Servidor

```bash
.venv/bin/python -m app                              # http://127.0.0.1:4000/api/v1
.venv/bin/uvicorn app.main:app --reload --port 4000  # recarga al guardar
```

La API no arranca en estos casos:

- no hay `FIRESTORE_EMULATOR_HOST` ni `FIREBASE_SERVICE_ACCOUNT_BASE64`
- `FIREBASE_SERVICE_ACCOUNT_BASE64` no contiene un JSON válido
- `FIREBASE_AUTH_EMULATOR_HOST` tiene valor sin `APP_ENV=local` y `FIRESTORE_EMULATOR_HOST` a la vez (ADR-50)
- existen `VERCEL` o `K_SERVICE` y falta `APP_ENV`
- `APP_ENV` tiene un valor fuera de `local | staging | production`
- `ALLOWED_ORIGIN_PATTERN` no es una expresión regular válida

Fuera de producción, Swagger queda en `/api/v1/docs` y el esquema en `/api/v1/openapi.json`. Con `APP_ENV=production` los dos responden 404. ReDoc está apagado.

## Variables de entorno

| Variable | Por defecto | Uso |
|---|---|---|
| `PORT` | `4000` | Puerto de `python -m app`. La imagen de Docker usa el `PORT` del contenedor, 8080 si no viene |
| `APP_ENV` | `local` | `local \| staging \| production`. Obligatoria en Vercel y Cloud Run (ADR-36) |
| `QUOTA_RESET_HOUR_LOCAL` y `QUOTA_RESET_TIMEZONE` | `0` y `America/Santiago` | Reinicio de cuota (ADR-11) |
| `FIRESTORE_EMULATOR_HOST` | sin valor | Solo en local. Si tiene valor, manda sobre la cuenta de servicio |
| `FIRESTORE_EMULATOR_PROJECT_ID` | `demo-aprueba` | Proyecto de Firestore con el emulador, el mismo con que se levanta. Sin emulador no se usa: Firestore toma el `project_id` de la cuenta de servicio (ADR-49) |
| `FIREBASE_PROJECT_ID` | sin valor | Solo para validar tokens: proyecto de Firebase Admin y audiencia (`aud`) que exige `verify_id_token` (ver Autenticación). Con el emulador, `aprueba-app-modulo-preguntas` si falta. Con cuenta de servicio, el `project_id` del JSON si falta. No cambia el proyecto de Firestore (ADR-49) |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | sin valor | JSON de la cuenta de servicio en base64, para Firestore y Firebase Admin (ADR-18). Es secreta |
| `FIREBASE_AUTH_EMULATOR_HOST` | sin valor | Solo en local, con `APP_ENV=local` y el emulador de Firestore. Con ella `firebase_admin` no verifica la firma de los tokens. En cualquier otro caso la API no arranca (ADR-50). Se lee solo del entorno del proceso: escrita en `.env` no tiene efecto |
| `ALLOWED_ORIGINS` | vacío | Orígenes exactos separados por comas (ADR-19) |
| `ALLOWED_ORIGIN_PATTERN` | sin valor | Expresión regular para las vistas previas de la app web |
| `SEED_ALLOW_REMOTE` | `false` | Habilita el seed fuera del emulador (ADR-22) |
| `SEED_DEMO_UID` | sin valor | UID de Firebase de `aprueba@demo.cl`. Lo exige el seed (ADR-58) |
| `SEED_DEMO_NEW_UID` | sin valor | UID de Firebase de `aprueba2@demo.cl`. Lo exige el seed (ADR-58) |

Una variable definida pero vacía cuenta como no definida.

## Contrato

Toda respuesta usa el envelope `{data, error, meta}`. En error, `data` es `null` y `error` trae `code`, `message`, `field` y `details`. `details` es una lista, vacía por defecto. En `VALIDATION_ERROR` lleva un elemento `{field, message, type}` por cada campo que falla, y `field` repite el del primero. `meta.requestId` es `req_` más 12 caracteres hexadecimales, y la cabecera `X-Request-Id` lleva el mismo valor. `meta.timestamp` va en UTC con milisegundos y `Z`.

El catálogo está en `app/core/errors.py` y tiene 21 códigos. A los diez estándar de Max y los nueve del módulo se suman `METHOD_NOT_ALLOWED` 405 (ADR-32) y `PAYLOAD_TOO_LARGE` 413 (ADR-33), propios de este backend. El mensaje sale en español, o en inglés si `Accept-Language` pide `en`. `ApiError` rechaza un código del catálogo con un status distinto del suyo.

Un POST, PUT o PATCH con `Content-Type: application/json` se revisa antes del enrutamiento. Un JSON inválido da 400 y un cuerpo sobre 100 kB da 413. Un error no controlado da 500 `INTERNAL_ERROR`, sin traza, y queda en el log con su `requestId`.

`GET /api/v1/health` responde:

```json
{
  "data": {
    "status": "ok",
    "service": "aprueba-questions-backend",
    "version": "1.0.0",
    "uptimeSeconds": 12,
    "environment": "local"
  },
  "error": null,
  "meta": {
    "requestId": "req_84f2c1a09b3e",
    "timestamp": "2026-09-23T14:00:00.000Z"
  }
}
```

`uptimeSeconds` cuenta desde que se importó el router. `HEAD /api/v1/health` responde 200 sin cuerpo (ADR-35).

## Autenticación

El alumno inicia sesión en la app con Firebase Auth y la app envía su ID token en `Authorization: Bearer`. El backend no emite ni renueva tokens y no tiene `JWT_SECRET` (ADR-40). `get_current_user`, en `app/core/deps.py`, valida el token con `firebase_admin.auth.verify_id_token` en el threadpool, porque la llamada bloquea mientras baja los certificados públicos de Google. Ninguna ruta usa todavía `CurrentUser` ni `OptionalUser`.

| Caso | Respuesta |
|---|---|
| Token válido | El usuario: `uid`, `email`, `role` y `plan`. `role` y `plan` salen de custom claims y valen `student` y `free` si no vienen (ADR-44) |
| Token vencido | 401 `AUTH_TOKEN_EXPIRED`. El mensaje le pide a la app un token nuevo de Firebase |
| Sin cabecera, esquema distinto de `Bearer`, token vacío o rechazado | 401 `AUTH_REQUIRED` |
| Certificados de Google no disponibles, o sin respuesta en 10 s | 503 `SERVICE_UNAVAILABLE` (ADR-45 y ADR-46) |
| `ValueError` de `firebase_admin`, que viene de la configuración | 500 `INTERNAL_ERROR`, registrado en el log (ADR-48) |

Todas llevan el envelope. `get_optional_user` devuelve `None` sin cabecera `Authorization` y el mismo 401 si la cabecera existe pero no sirve (ADR-51). La verificación usa `check_revoked=False`, así que un token revocado sirve hasta que expira, como máximo una hora (ADR-43), y tolera 5 s de diferencia de reloj (ADR-47).

`get_firebase_app()`, en `app/db/firestore.py`, inicia Firebase Admin con la misma configuración que Firestore. Con `FIRESTORE_EMULATOR_HOST` usa una credencial anónima, porque verificar un token solo necesita los certificados públicos. Con `FIREBASE_SERVICE_ACCOUNT_BASE64` usa la cuenta de servicio (ADR-49). El proyecto que resulta es la audiencia que exige `verify_id_token`. La app pide sus tokens al proyecto `aprueba-app-modulo-preguntas`, así que en local `FIREBASE_PROJECT_ID` vale lo mismo, mientras Firestore usa el proyecto `demo-aprueba` del emulador. Lo decidió el equipo el 2026-09-24 y lo ajustó el 2026-09-25 (ADR-49). Con otro valor, la API local rechaza los tokens de la app con 401 `AUTH_REQUIRED`.

## Pruebas

```bash
.venv/bin/python -m pytest
```

Son 31: 10 en `tests/test_health.py` y 21 en `tests/test_core.py`. `test_paginacion_por_fecha_contra_el_emulador` necesita el emulador en `127.0.0.1:8080`. Sin él, pytest informa 30 aprobadas y 1 omitida. Las pruebas no leen el `.env` local: `tests/conftest.py` fija su propio entorno y quita `FIREBASE_AUTH_EMULATOR_HOST`. Starlette 1.7 deja un aviso de obsolescencia sobre `httpx`, que se fijó en 0.28.1 como pedía el encargo.

Las pruebas de autenticación están en `tests/test_core.py` y montan rutas de sonda (`/api/v1/_yo` y `/api/v1/_opcional`) solo dentro de la prueba. Casi todas reemplazan `verify_id_token` con `monkeypatch` y comprueban que corra fuera del event loop:

- `test_token_de_firebase_valido_entrega_el_usuario`
- `test_token_de_firebase_expirado_da_auth_token_expired`, que revisa el envelope completo en español y en inglés
- `test_token_de_firebase_invalido_da_auth_required`
- `test_error_de_configuracion_en_verify_id_token_da_500`
- `test_verify_id_token_real_con_firma_local`, que corre el `verify_id_token` real con tokens RS256 firmados por una llave generada durante la prueba y sin bajar certificados
- `test_sin_bearer_da_auth_required_sin_llamar_a_firebase`
- `test_certificados_de_google_no_disponibles_da_503`
- `test_usuario_opcional`

En `tests/test_health.py`, `test_08_firebase_admin_con_la_configuracion_de_firestore` reemplazó a `test_08_produccion_sin_jwt_secret_no_arranca`. Revisa la credencial en modo emulador, la cuenta de servicio, `httpTimeout` y la guarda de `FIREBASE_AUTH_EMULATOR_HOST`. Ninguna prueba usa red ni credenciales reales.

## Docker y Cloud Run

```bash
cd backend
docker build -t aprueba-api .
```

La imagen parte de `python:3.12-slim`, instala solo `requirements.txt`, copia `app/` y corre como el usuario sin privilegios `api`. Uvicorn escucha en `$PORT`, 8080 si no viene, con `--proxy-headers` y `--forwarded-allow-ips '*'`. Así, detrás del proxy de Cloud Run, el 307 que Starlette da a una ruta con barra final apunta a `https`. `.dockerignore` deja fuera `.venv`, `tests`, las cachés y los `.env`.

El servicio de Cloud Run todavía no existe, y la imagen no se ha construido porque la máquina donde se hizo el port no tiene Docker. El código no usa las credenciales predeterminadas de Google Cloud, así que en Cloud Run también exige `FIREBASE_SERVICE_ACCOUNT_BASE64`. Como Cloud Run define `K_SERVICE`, `APP_ENV` es obligatoria ahí.

## Vercel

La API se despliega en el proyecto `aprueba-app-modulo-preguntas-api`, con Root Directory `backend/`. `vercel.json` declara el preset `fastapi` con `app/main.py` como función, la región `gru1` (ADR-25) y deja fuera `tests/` y `.pytest_cache/`. `git.deploymentEnabled` solo habilita `main` (ADR-26). Vercel instala `requirements.txt` y toma la versión de `.python-version`.

`APP_ENV` existe en el proyecto de Vercel desde el 2026-09-24, con `production` en production y en preview. Vercel define `VERCEL=1`, así que sin `APP_ENV` la función no arranca (ADR-36). `NODE_ENV`, `JWT_SECRET`, `JWT_EXPIRES_IN` y `REFRESH_TOKEN_EXPIRES_IN` ya no las lee nadie y se borran al desplegar FastAPI (ADR-40). `FIREBASE_AUTH_EMULATOR_HOST` no se define en Vercel.

Las reglas y los índices de Firestore se publican aparte, desde la raíz del repositorio, con `firebase.json`.
