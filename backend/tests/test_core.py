"""Pruebas de lo que agrega el port a FastAPI: 405, HEAD, validación, JSON malformado, idioma,
autenticación, cursor, 500 y documentación OpenAPI."""
import asyncio
import base64
import json
import socket
import time
from datetime import datetime, timedelta, timezone
from typing import Annotated

import jwt
import pytest
from fastapi import Depends, Header
from fastapi.testclient import TestClient
from google.api_core.datetime_helpers import DatetimeWithNanoseconds
from google.cloud.firestore import AsyncClient
from pydantic import Field

from app.core.config import Settings, get_settings
from app.core.deps import CurrentUser, OptionalUser
from app.core.envelope import ok
from app.core.errors import MAX_JSON_BODY, ApiError
from app.core.pagination import PageParams, decode_cursor, encode_cursor, paginate
from app.main import app, create_app
from app.schemas.common import CamelModel

client = TestClient(app)


class Muestra(CamelModel):
    nombre_completo: str = Field(min_length=3)


@pytest.fixture
def prueba():
    """App nueva con rutas que solo existen en las pruebas."""
    a = create_app()

    @a.post("/api/v1/_prueba")
    async def crear(body: Muestra):
        return ok(body)

    @a.get("/api/v1/_yo")
    async def yo(user: CurrentUser):
        return ok(user)

    @a.get("/api/v1/_opcional")
    async def opcional(user: OptionalUser):
        return ok(user)

    @a.get("/api/v1/_pagina")
    async def pagina(page: PageParams = Depends()):
        return ok({"cursor": decode_cursor(page.cursor), "limit": page.limit})

    @a.get("/api/v1/_cabecera")
    async def cabecera(x_intentos: Annotated[int, Header()]):
        return ok(x_intentos)

    @a.get("/api/v1/_falla")
    async def falla():
        raise RuntimeError("detalle interno que no debe salir")

    return TestClient(a, raise_server_exceptions=False)


def test_405_metodo_no_permitido_con_envelope():
    res = client.post("/api/v1/health")
    assert res.status_code == 405
    body = res.json()
    assert body["data"] is None
    assert body["error"]["code"] == "METHOD_NOT_ALLOWED"
    assert body["meta"]["requestId"] == res.headers["x-request-id"]
    assert res.headers["allow"] == "GET"  # Starlette informa solo la primera ruta que calza, no HEAD


def test_head_en_health_como_express():
    res = client.head("/api/v1/health")
    assert res.status_code == 200
    assert res.content == b""


def test_validacion_400_con_details_por_campo(prueba):
    res = prueba.post("/api/v1/_prueba", json={"nombreCompleto": "ab", "sobra": 1})
    assert res.status_code == 400
    error = res.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert error["field"] == "nombreCompleto"
    assert {(d["field"], d["type"]) for d in error["details"]} == {
        ("nombreCompleto", "string_too_short"), ("sobra", "extra_forbidden")}
    assert all(d["message"] for d in error["details"])

    # Un error sobre el cuerpo completo deja field en null; en cabeceras se quita el prefijo header.
    for kwargs in ({}, {"json": [1]}):
        error = prueba.post("/api/v1/_prueba", **kwargs).json()["error"]
        assert error["field"] is None and error["details"][0]["field"] is None, kwargs
    error = prueba.get("/api/v1/_cabecera", headers={"x-intentos": "zz"}).json()["error"]
    assert error["field"] == "x-intentos"

    # El cuerpo válido llega intacto a la ruta después del middleware de JSON.
    res = prueba.post("/api/v1/_prueba", json={"nombreCompleto": "Ana Pérez"})
    assert res.status_code == 200
    assert res.json()["data"] == {"nombreCompleto": "Ana Pérez"}


def test_json_malformado_400_antes_del_enrutamiento(prueba):
    json_ct = {"Content-Type": "application/json; charset=utf-8"}
    # Truncado, y lo que express.json() rechaza en modo estricto: escalares y NaN.
    # Anidar más hondo que el límite de recursión de Python también es 400, no 500.
    for cuerpo in (b'{"nombreCompleto": ', b"123", b'"texto"', b'{"n": NaN}', b"[" * 5000, b"[" * 5000 + b"]" * 5000):
        for res in (client.post("/api/v1/health", content=cuerpo, headers=json_ct),
                    prueba.post("/api/v1/_prueba", content=cuerpo, headers=json_ct)):
            assert res.status_code == 400, cuerpo[:20]
            body = res.json()
            assert body["error"]["code"] == "VALIDATION_ERROR"
            assert body["error"]["message"] == "El cuerpo de la petición no contiene un JSON válido."
            assert body["error"]["details"] == [{"field": None, "message": "JSON decode error", "type": "json_invalid"}]
            assert body["meta"]["requestId"] == res.headers["x-request-id"]

    # Un BOM UTF-8 y espacios al inicio no invalidan un objeto.
    res = prueba.post("/api/v1/_prueba", content=b'\xef\xbb\xbf \n{"nombreCompleto": "Ana"}', headers=json_ct)
    assert res.status_code == 200

    # Tope de 100 kB, como express.json(): justo en el tope pasa, un byte más da 413 con el envelope.
    relleno = MAX_JSON_BODY - len(b'{"nombreCompleto": ""}')
    res = prueba.post("/api/v1/_prueba", content=b'{"nombreCompleto": "' + b"a" * relleno + b'"}', headers=json_ct)
    assert res.status_code == 200
    res = prueba.post("/api/v1/_prueba", content=b'{"nombreCompleto": "' + b"a" * (relleno + 1) + b'"}',
                      headers={**json_ct, "Origin": "https://app.aprueba.test"})
    assert (res.status_code, res.json()["error"]["code"]) == (413, "PAYLOAD_TOO_LARGE")
    assert res.headers["access-control-allow-origin"] == "https://app.aprueba.test"


def test_mensaje_en_ingles_con_accept_language():
    res = client.get("/api/v1/no-existe", headers={"Accept-Language": "en-US,en;q=0.9"})
    assert res.json()["error"]["message"] == "The requested resource does not exist."
    res = client.get("/api/v1/no-existe")
    assert res.json()["error"]["message"] == "El recurso solicitado no existe."


def test_get_current_user(prueba):
    secret = get_settings().jwt_secret

    def token(**claims):
        return {"Authorization": "Bearer " + jwt.encode(claims, secret, algorithm="HS256")}

    res = prueba.get("/api/v1/_yo", headers=token(sub="usr_demo", email="a@b.cl", exp=int(time.time()) + 60))
    assert res.status_code == 200
    assert res.json()["data"] == {"uid": "usr_demo", "email": "a@b.cl", "role": "student", "plan": "free"}

    expirado = prueba.get("/api/v1/_yo", headers=token(sub="usr_demo", exp=int(time.time()) - 60))
    assert (expirado.status_code, expirado.json()["error"]["code"]) == (401, "AUTH_TOKEN_EXPIRED")

    ajeno = {"Authorization": "Bearer " + jwt.encode({"sub": "usr_demo"}, "x" * 40, algorithm="HS256")}
    for headers in (ajeno, {"Authorization": "Bearer basura"}, {}):
        res = prueba.get("/api/v1/_yo", headers=headers)
        assert (res.status_code, res.json()["error"]["code"]) == (401, "AUTH_REQUIRED")

    assert prueba.get("/api/v1/_opcional").json()["data"] is None

    # Lo que jsonwebtoken.verify aceptaba y PyJWT rechaza por defecto: aud, sub numérico, jti numérico, iat futuro.
    for claims in ({"sub": "usr_demo", "aud": "otra"}, {"sub": 5}, {"sub": "usr_demo", "jti": 7},
                   {"sub": "usr_demo", "iat": int(time.time()) + 3600}):
        assert prueba.get("/api/v1/_yo", headers=token(**claims)).status_code == 200, claims


def test_cursor_corrupto_da_validation_error(prueba):
    cursor = encode_cursor("2026-09-23", "q_lectora_001")
    assert decode_cursor(cursor) == {"v": "2026-09-23", "id": "q_lectora_001"}
    # Una fecha vuelve como fecha, para que start_after compare contra un timestamp y no contra texto.
    fecha = DatetimeWithNanoseconds(2026, 9, 23, 12, 0, 0, 123456, tzinfo=timezone.utc)
    assert decode_cursor(encode_cursor(fecha, "usr_demo"))["v"] == fecha

    def b64(obj):
        return base64.urlsafe_b64encode(json.dumps(obj).encode()).decode()

    # basura, texto que no es JSON, JSON que no es objeto, e id que no sirve como documento
    malos = ["%%%", "bm8gZXMganNvbg", "WzFd"] + [b64({"v": "x", "id": i}) for i in ({"a": 1}, "a/b", "", 5, None)]
    malos.append(b64({"v": "no es fecha", "t": "ts", "id": "x"}))
    for malo in malos:
        with pytest.raises(ApiError) as exc:
            decode_cursor(malo)
        assert (exc.value.status, exc.value.code, exc.value.field) == (400, "VALIDATION_ERROR", "cursor"), malo

    res = prueba.get("/api/v1/_pagina", params={"cursor": "%%%"})
    assert res.status_code == 400
    assert res.json()["error"]["field"] == "cursor"
    assert res.json()["error"]["details"] == [{"field": "cursor", "message": "Invalid cursor", "type": "cursor_invalid"}]
    res = prueba.get("/api/v1/_pagina", params={"limit": 101})
    assert (res.status_code, res.json()["error"]["field"]) == (400, "limit")


def test_error_no_controlado_500_sin_trazas(prueba, caplog):
    res = prueba.get("/api/v1/_falla", headers={"Origin": "https://app.aprueba.test"})
    assert res.status_code == 500
    body = res.json()
    assert body["error"]["code"] == "INTERNAL_ERROR"
    assert "detalle interno" not in res.text
    assert body["meta"]["requestId"] == res.headers["x-request-id"]
    assert body["meta"]["requestId"] in caplog.text
    # Con CORS, para que la app web pueda leer el envelope del 500.
    assert res.headers["access-control-allow-origin"] == "https://app.aprueba.test"


def test_docs_solo_fuera_de_produccion(monkeypatch):
    assert client.get("/api/v1/docs").status_code == 200
    spec = client.get("/api/v1/openapi.json").json()
    # El health publica su envelope, no un esquema vacío.
    schema = spec["paths"]["/api/v1/health"]["get"]["responses"]["200"]["content"]["application/json"]["schema"]
    assert schema == {"$ref": "#/components/schemas/HealthResponse"}
    assert "uptimeSeconds" in spec["components"]["schemas"]["HealthOut"]["properties"]
    monkeypatch.setenv("APP_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "s" * 32)
    produccion = TestClient(create_app())
    assert produccion.get("/api/v1/docs").status_code == 404
    assert produccion.get("/api/v1/openapi.json").status_code == 404
    assert produccion.get("/api/v1/health").json()["data"]["environment"] == "production"


@pytest.mark.parametrize("plataforma", ["VERCEL", "K_SERVICE"])
def test_app_env_obligatorio_en_vercel_y_cloud_run(monkeypatch, plataforma):
    monkeypatch.setenv(plataforma, "1")
    monkeypatch.delenv("APP_ENV")
    with pytest.raises(RuntimeError, match="APP_ENV es obligatorio en Vercel y en Cloud Run."):
        Settings()
    monkeypatch.setenv("APP_ENV", "staging")
    assert Settings().app_env == "staging"


def test_patron_cors_invalido_no_arranca(monkeypatch):
    monkeypatch.setenv("ALLOWED_ORIGIN_PATTERN", "^https://(mal")
    with pytest.raises(Exception, match=r"missing \)"):
        create_app()


def test_fechas_en_utc_con_z():
    class Fila(CamelModel):
        creado_en: datetime

    exacta = datetime(2026, 9, 18, 12, tzinfo=timezone.utc)
    con_fraccion = DatetimeWithNanoseconds(2026, 9, 18, 12, 0, 0, 123456, tzinfo=timezone.utc)
    for valor, esperado in ((exacta, "2026-09-18T12:00:00Z"), (con_fraccion, "2026-09-18T12:00:00.123456Z")):
        de_dict = json.loads(ok({"creadoEn": valor}).body)["data"]["creadoEn"]
        de_modelo = json.loads(ok(Fila(creado_en=valor)).body)["data"]["creadoEn"]
        assert de_dict == de_modelo == esperado, valor
    # Fuera de un modelo, una hora con desfase se pasa a UTC. Un CamelModel conserva el desfase que recibe.
    santiago = datetime(2026, 9, 18, 9, tzinfo=timezone(timedelta(hours=-3)))
    assert json.loads(ok({"creadoEn": santiago}).body)["data"]["creadoEn"] == "2026-09-18T12:00:00Z"


def _emulador_activo() -> bool:
    try:
        socket.create_connection(("127.0.0.1", 8080), timeout=0.5).close()
        return True
    except OSError:
        return False


@pytest.mark.skipif(not _emulador_activo(), reason="emulador de Firestore apagado en 127.0.0.1:8080")
def test_paginacion_por_fecha_contra_el_emulador():
    """Sección 9.4 de Max: paginate() contra el emulador, ordenando por una fecha en ambos sentidos."""
    async def recorrer():
        col = AsyncClient(project="demo-pytest").collection("paginacion")
        base = datetime(2026, 9, 1, tzinfo=timezone.utc)
        for i in range(3):
            await col.document(f"d{i}").set({"createdAt": base + timedelta(seconds=i)})
        vistos = {}
        try:
            for desc in (False, True):
                ids, cursor = [], None
                for _ in range(5):  # tope por si el cursor vuelve a ciclar
                    items, m = await paginate(col, PageParams(limit=1, cursor=cursor), "createdAt", desc)
                    ids += [x["id"] for x in items]
                    cursor = m["pagination"]["nextCursor"]
                    if not cursor:
                        break
                vistos[desc] = ids
        finally:
            for i in range(3):
                await col.document(f"d{i}").delete()
        return vistos

    assert asyncio.run(recorrer()) == {False: ["d0", "d1", "d2"], True: ["d2", "d1", "d0"]}
