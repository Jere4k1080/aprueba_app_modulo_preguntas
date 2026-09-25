"""Pruebas de lo que agrega el port a FastAPI: 405, HEAD, validación, JSON malformado, idioma,
autenticación, cursor, 500 y documentación OpenAPI."""
import asyncio
import base64
import json
import socket
import time
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from typing import Annotated

import firebase_admin
import google.oauth2.id_token
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID
from fastapi import Depends, Header
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth
from google.api_core.datetime_helpers import DatetimeWithNanoseconds
from google.cloud.firestore import AsyncClient
from pydantic import Field

from app.core.config import Settings
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


BEARER = {"Authorization": "Bearer token.de.firebase"}
BASIC = {"Authorization": "Basic dXNyOmNsYXZl"}


@pytest.fixture
def verify(monkeypatch):
    """Reemplaza firebase_admin.auth.verify_id_token, sin red ni credenciales. resultado son
    los claims que devuelve o la excepción que lanza; llamadas guarda cada invocación."""
    fake = SimpleNamespace(resultado={"uid": "usr_demo", "sub": "usr_demo", "email": "a@b.cl"}, llamadas=[])

    def verify_id_token(token, **kwargs):
        # Bloquea mientras baja certificados: tiene que correr en el threadpool, fuera del event loop.
        with pytest.raises(RuntimeError):
            asyncio.get_running_loop()
        fake.llamadas.append((token, kwargs))
        if isinstance(fake.resultado, Exception):
            raise fake.resultado
        return fake.resultado

    monkeypatch.setattr(firebase_auth, "verify_id_token", verify_id_token)
    return fake


def test_token_de_firebase_valido_entrega_el_usuario(prueba, verify):
    res = prueba.get("/api/v1/_yo", headers=BEARER)
    assert res.status_code == 200
    assert res.json()["data"] == {"uid": "usr_demo", "email": "a@b.cl", "role": "student", "plan": "free"}
    firebase_app = firebase_admin.get_app()
    assert verify.llamadas == [("token.de.firebase", {"app": firebase_app, "check_revoked": False,
                                                      "clock_skew_seconds": 5})]
    assert firebase_app.project_id == "aprueba-app-modulo-preguntas"

    # role y plan salen de los custom claims cuando vienen.
    verify.resultado = {"uid": "usr_demo", "role": "admin", "plan": "premium"}
    assert prueba.get("/api/v1/_yo", headers=BEARER).json()["data"] == {
        "uid": "usr_demo", "email": None, "role": "admin", "plan": "premium"}


def test_token_de_firebase_expirado_da_auth_token_expired(prueba, verify):
    verify.resultado = firebase_auth.ExpiredIdTokenError("Token expired", cause=None)
    for idioma, mensaje in (
            ({}, "El token de acceso expiró. La app debe pedir uno nuevo a Firebase y reintentar."),
            ({"Accept-Language": "en"}, "The access token expired. The app must request a new one from Firebase and retry.")):
        res = prueba.get("/api/v1/_yo", headers={**BEARER, **idioma})
        assert res.status_code == 401
        body = res.json()
        assert body["data"] is None
        assert body["error"] == {"code": "AUTH_TOKEN_EXPIRED", "message": mensaje, "field": None, "details": []}
        assert body["meta"]["requestId"] == res.headers["x-request-id"]
        assert body["meta"]["timestamp"]


def test_token_de_firebase_invalido_da_auth_required(prueba, verify):
    verify.resultado = firebase_auth.InvalidIdTokenError("firma inválida")
    for idioma, mensaje in (({}, "Falta el token de acceso o es inválido."),
                            ({"Accept-Language": "en"}, "Missing or invalid access token.")):
        res = prueba.get("/api/v1/_yo", headers={**BEARER, **idioma})
        assert (res.status_code, res.json()["error"]["code"]) == (401, "AUTH_REQUIRED")
        assert res.json()["error"]["message"] == mensaje


def test_error_de_configuracion_en_verify_id_token_da_500(prueba, verify):
    # firebase_admin lanza ValueError sin ID de proyecto o con FIREBASE_AUTH_EMULATOR_HOST mal
    # escrita. Como 401, la app renovaría el token y cerraría la sesión sin dejar rastro en el log.
    verify.resultado = ValueError('Invalid FIREBASE_AUTH_EMULATOR_HOST: "http://127.0.0.1:9099"')
    res = prueba.get("/api/v1/_yo", headers=BEARER)
    assert (res.status_code, res.json()["error"]["code"]) == (500, "INTERNAL_ERROR")


@pytest.fixture
def firmar(monkeypatch):
    """Firma tokens RS256 con una llave local y reemplaza la descarga de certificados de Google.
    Así corre el verify_id_token real de firebase_admin, sin red."""
    llave = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    nombre = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "prueba")])
    ahora = datetime.now(timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(nombre).issuer_name(nombre).public_key(llave.public_key())
            .serial_number(1).not_valid_before(ahora - timedelta(days=1)).not_valid_after(ahora + timedelta(days=1))
            .sign(llave, hashes.SHA256()))
    pem = cert.public_bytes(serialization.Encoding.PEM).decode()
    monkeypatch.setattr(google.oauth2.id_token, "_fetch_certs", lambda request, url: {"k1": pem})

    def b64(raw: bytes) -> str:
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    def firmar_token(iat_adelantado=0, vence_en=3600, header=None):
        t = int(time.time())
        payload = {"iss": "https://securetoken.google.com/aprueba-app-modulo-preguntas", "aud": "aprueba-app-modulo-preguntas", "sub": "usr_real",
                   "iat": t + iat_adelantado, "exp": t + vence_en}
        firmado = b64(json.dumps(header or {"alg": "RS256", "kid": "k1"}).encode()) + "." + b64(json.dumps(payload).encode())
        return firmado + "." + b64(llave.sign(firmado.encode(), padding.PKCS1v15(), hashes.SHA256()))

    return firmar_token


def test_verify_id_token_real_con_firma_local(prueba, firmar):
    def yo(token):
        return prueba.get("/api/v1/_yo", headers={"Authorization": f"Bearer {token}"})

    # Válido, también con el reloj del servidor 2 s atrasado respecto de Google.
    for token in (firmar(), firmar(iat_adelantado=2)):
        res = yo(token)
        assert (res.status_code, res.json()["data"]["uid"]) == (200, "usr_real")
    # firebase_admin distingue el vencido por el texto 'Token expired' de google-auth.
    assert yo(firmar(vence_en=-60)).json()["error"]["code"] == "AUTH_TOKEN_EXPIRED"
    # Mal formados que en firebase_admin 7.7.0 lanzan TypeError: sin kid y con d numérico (no pide
    # certificados), y con kid en una lista (falla al buscarlo entre los certificados).
    for token in ("eyJhbGciOiJIUzI1NiJ9.eyJ2IjowLCJkIjo1fQ.AAAA", firmar(header={"alg": "RS256", "kid": ["k1"]})):
        res = yo(token)
        assert (res.status_code, res.json()["error"]["code"]) == (401, "AUTH_REQUIRED"), token


def test_sin_bearer_da_auth_required_sin_llamar_a_firebase(prueba, verify):
    for headers in ({}, BASIC, {"Authorization": "Bearer "}, {"Authorization": "Bearer"}):
        res = prueba.get("/api/v1/_yo", headers=headers)
        assert (res.status_code, res.json()["error"]["code"]) == (401, "AUTH_REQUIRED"), headers
    assert verify.llamadas == []


def test_certificados_de_google_no_disponibles_da_503(prueba, verify):
    verify.resultado = firebase_auth.CertificateFetchError("sin red", cause=None)
    res = prueba.get("/api/v1/_yo", headers=BEARER)
    assert (res.status_code, res.json()["error"]["code"]) == (503, "SERVICE_UNAVAILABLE")


def test_usuario_opcional(prueba, verify):
    assert prueba.get("/api/v1/_opcional").json()["data"] is None
    assert prueba.get("/api/v1/_opcional", headers=BEARER).json()["data"]["uid"] == "usr_demo"
    # Una cabecera presente pero inválida no se trata como anónima.
    verify.resultado = firebase_auth.InvalidIdTokenError("firma inválida")
    for headers in (BEARER, BASIC):
        res = prueba.get("/api/v1/_opcional", headers=headers)
        assert (res.status_code, res.json()["error"]["code"]) == (401, "AUTH_REQUIRED"), headers


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
