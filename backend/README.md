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
| `google-auth` | 2.58.0 | Credenciales de la cuenta de servicio |
| `PyJWT` | 2.15.0 | Verificación de tokens HS256 |
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
│   │   ├── deps.py          get_current_user, get_optional_user y los alias DB, CurrentUser y OptionalUser
│   │   └── pagination.py    encode_cursor(), decode_cursor(), PageParams y paginate()
│   ├── db/firestore.py      AsyncClient único y nombres de colecciones (COL)
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

Queda en `127.0.0.1:8080`, que es el valor de `FIRESTORE_EMULATOR_HOST` en `.env.example`, y carga `firestore.rules`, el archivo de reglas que declara `firebase.json`. Necesita Node.js, solo para `npx`, y Java 21. El prefijo `demo-` hace que el emulador no busque un proyecto real. No uses aquí el ID `aprueba-app-modulo-preguntas`.

## Datos de prueba

```bash
.venv/bin/python -m app.seed
```

El seed lee los JSON de `app/seed/data/` y escribe `tests`, `skills`, `questions`, `users`, `answers` y `corrections`, más `users/usr_demo/medalLedger` y `users/{uid}/state/practice`. Usa IDs fijos con `set()`, así que otra corrida reescribe los mismos documentos. Las fechas las pone el servidor de Firestore con `SERVER_TIMESTAMP` (ADR-14). `quota.date` y `lastActiveDate` toman la fecha del día en `QUOTA_RESET_TIMEZONE`. Los esquemas están en [`seed/README.md`](../seed/README.md).

Sin `FIRESTORE_EMULATOR_HOST` el seed exige `SEED_ALLOW_REMOTE=true`. Si falta, termina con código 1 antes de abrir Firestore (ADR-22). Para el proyecto real se corre desde `backend/`, porque pydantic-settings lee el `.env` del directorio actual. `FIREBASE_SERVICE_ACCOUNT_BASE64` se define solo para esa ejecución, con la cuenta de servicio leída desde un JSON fuera del repositorio.

## Servidor

```bash
.venv/bin/python -m app                              # http://127.0.0.1:4000/api/v1
.venv/bin/uvicorn app.main:app --reload --port 4000  # recarga al guardar
```

La API no arranca en estos casos:

- no hay `FIRESTORE_EMULATOR_HOST` ni `FIREBASE_SERVICE_ACCOUNT_BASE64`
- `FIREBASE_SERVICE_ACCOUNT_BASE64` no contiene un JSON válido
- `APP_ENV=production` sin `JWT_SECRET`, o con un valor hecho solo de espacios
- existen `VERCEL` o `K_SERVICE` y falta `APP_ENV`
- `APP_ENV` tiene un valor fuera de `local | staging | production`
- `ALLOWED_ORIGIN_PATTERN` no es una expresión regular válida

Fuera de producción, Swagger queda en `/api/v1/docs` y el esquema en `/api/v1/openapi.json`. Con `APP_ENV=production` los dos responden 404. ReDoc está apagado.

## Variables de entorno

| Variable | Por defecto | Uso |
|---|---|---|
| `PORT` | `4000` | Puerto de `python -m app`. La imagen de Docker usa el `PORT` del contenedor, 8080 si no viene |
| `APP_ENV` | `local` | `local \| staging \| production`. Obligatoria en Vercel y Cloud Run (ADR-36) |
| `JWT_SECRET` | vacío | Obligatoria en producción (ADR-20). Fuera de producción se usa un valor de desarrollo |
| `JWT_EXPIRES_IN` y `REFRESH_TOKEN_EXPIRES_IN` | `15m` y `30d` | Se leen, pero ningún código emite tokens todavía |
| `QUOTA_RESET_HOUR_LOCAL` y `QUOTA_RESET_TIMEZONE` | `0` y `America/Santiago` | Reinicio de cuota (ADR-11) |
| `FIRESTORE_EMULATOR_HOST` | sin valor | Solo en local. Si tiene valor, manda sobre la cuenta de servicio |
| `FIREBASE_PROJECT_ID` | sin valor | Con el emulador, `aprueba-dev` si falta. Con cuenta de servicio, el `project_id` del JSON si falta |
| `FIREBASE_SERVICE_ACCOUNT_BASE64` | sin valor | JSON de la cuenta de servicio en base64 (ADR-18) |
| `ALLOWED_ORIGINS` | vacío | Orígenes exactos separados por comas (ADR-19) |
| `ALLOWED_ORIGIN_PATTERN` | sin valor | Expresión regular para las vistas previas de la app web |
| `SEED_ALLOW_REMOTE` | `false` | Habilita el seed fuera del emulador (ADR-22) |

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

## Pruebas

```bash
.venv/bin/python -m pytest
```

Son 24: 10 en `tests/test_health.py` y 14 en `tests/test_core.py`. `test_paginacion_por_fecha_contra_el_emulador` necesita el emulador en `127.0.0.1:8080`. Sin él, pytest informa 23 aprobadas y 1 omitida. Las pruebas no leen el `.env` local: `tests/conftest.py` fija su propio entorno. Starlette 1.7 deja un aviso de obsolescencia sobre `httpx`, que se fijó en 0.28.1 como pedía el encargo.

## Docker y Cloud Run

```bash
cd backend
docker build -t aprueba-api .
```

La imagen parte de `python:3.12-slim`, instala solo `requirements.txt`, copia `app/` y corre como el usuario sin privilegios `api`. Uvicorn escucha en `$PORT`, 8080 si no viene, con `--proxy-headers` y `--forwarded-allow-ips '*'`. Así, detrás del proxy de Cloud Run, el 307 que Starlette da a una ruta con barra final apunta a `https`. `.dockerignore` deja fuera `.venv`, `tests`, las cachés y los `.env`.

El servicio de Cloud Run todavía no existe, y la imagen no se ha construido porque la máquina donde se hizo el port no tiene Docker. El código no usa las credenciales predeterminadas de Google Cloud, así que en Cloud Run también exige `FIREBASE_SERVICE_ACCOUNT_BASE64`. Como Cloud Run define `K_SERVICE`, `APP_ENV` es obligatoria ahí.

## Vercel

La API se despliega en el proyecto `aprueba-app-modulo-preguntas-api`, con Root Directory `backend/`. `vercel.json` declara el preset `fastapi` con `app/main.py` como función, la región `gru1` (ADR-25) y deja fuera `tests/` y `.pytest_cache/`. `git.deploymentEnabled` solo habilita `main` (ADR-26). Vercel instala `requirements.txt` y toma la versión de `.python-version`.

`APP_ENV` existe en el proyecto de Vercel desde el 2026-09-24, con `production` en production y en preview. Vercel define `VERCEL=1`, así que sin `APP_ENV` la función no arranca (ADR-36). `NODE_ENV` ya no la lee nadie y se borra al desplegar FastAPI.

Las reglas y los índices de Firestore se publican aparte, desde la raíz del repositorio, con `firebase.json`.
