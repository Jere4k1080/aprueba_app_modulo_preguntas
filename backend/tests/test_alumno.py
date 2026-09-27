"""Alumno de cada petición (ADR-65, ADR-66, ADR-68 y ADR-71) y GET /me, contra el emulador de Firestore."""
import asyncio
import socket
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth
from google.cloud import firestore

import app.db.firestore as firestore_db
from app.core.config import get_settings
from app.main import create_app
from app.services import users
from app.services.users import new_user, quota_day

PROYECTO = "demo-pytest-alumno"
UID = "alumnoPrueba0000000000000001"  # 28 caracteres, como un UID de Firebase
BEARER = {"Authorization": "Bearer token.de.firebase"}
FREE = {"limits": {"qDay": 10}}


def _emulador_activo() -> bool:
    try:
        socket.create_connection(("127.0.0.1", 8080), timeout=0.5).close()
        return True
    except OSError:
        return False


pytestmark = pytest.mark.skipif(not _emulador_activo(), reason="emulador de Firestore apagado en 127.0.0.1:8080")


def claims(uid=UID, **extra) -> dict:
    """Claims de un ID token de Firebase con correo y contraseña, recién emitido."""
    return {"uid": uid, "sub": uid, "email": "alumna@demo.cl", "firebase": {"sign_in_provider": "password"},
            "auth_time": int(time.time()), **extra}


@pytest.fixture
def api(monkeypatch):
    monkeypatch.setenv("FIRESTORE_EMULATOR_PROJECT_ID", PROYECTO)
    monkeypatch.setattr(firestore_db, "_client", None)
    get_settings.cache_clear()
    token = claims()
    monkeypatch.setattr(firebase_auth, "verify_id_token", lambda _t, **_k: dict(token))
    db = firestore.Client(project=PROYECTO)
    db.collection("plans").document("free").set(FREE)
    try:
        # Un solo event loop para todas las peticiones: el cliente asíncrono de Firestore queda atado al primero.
        with TestClient(create_app()) as cliente:
            yield SimpleNamespace(cliente=cliente, db=db, token=token,
                                  ref=db.collection("users").document(f"usr_{UID}"))
    finally:
        pedido = urllib.request.Request(
            f"http://127.0.0.1:8080/emulator/v1/projects/{PROYECTO}/databases/(default)/documents", method="DELETE")
        urllib.request.urlopen(pedido, timeout=10).close()


def test_alta_nueva_con_la_forma_de_la_administracion(api):
    api.token.update(name="Alumna Nueva")
    res = api.cliente.get("/api/v1/me", headers={**BEARER, "Accept-Language": "en"})
    assert res.status_code == 200, res.text
    doc = api.ref.get().to_dict()
    esperado = new_user(api.token, "en", FREE, quota_day())
    fechas = ("createdAt", "updatedAt", "lastActivityAt")
    assert set(doc) == set(esperado), "el alta tiene que dejar los campos de new_user(), ni más ni menos"
    assert all(isinstance(doc[c], datetime) for c in fechas), "fechas del servidor"
    assert {k: v for k, v in doc.items() if k not in fechas} == {k: v for k, v in esperado.items() if k not in fechas}
    data = res.json()["data"]
    assert (data["id"], data["name"], data["language"], data["onboarded"]) == (f"usr_{UID}", "Alumna Nueva", "en", False)
    assert data["quota"] == {"used": 0, "max": 10, "unlimited": False}


def test_alta_repetida_no_pisa_el_documento(api):
    existente = {"name": "Otra", "plan": "all", "state": "active", "medalWallet": {"bronze": 7},
                 "quota": {"used": 3, "max": 0, "date": quota_day(), "unlimited": True},
                 "lastActivityAt": datetime.now(timezone.utc)}
    api.ref.set(existente)
    assert api.cliente.get("/api/v1/me", headers=BEARER).status_code == 200
    despues = api.ref.get().to_dict()
    assert {k: despues[k] for k in ("name", "plan", "medalWallet", "quota")} == \
        {k: existente[k] for k in ("name", "plan", "medalWallet", "quota")}

    # Carrera: la transacción del alta encuentra el documento que otra petición acaba de crear.
    async def carrera():
        db = firestore.AsyncClient(project=PROYECTO)
        return await users.create_user(db, db.collection("users").document(f"usr_{UID}"), claims(), "es")

    assert asyncio.run(carrera())["plan"] == "all"
    assert api.ref.get().to_dict()["name"] == "Otra", "la transacción no pisa un documento existente"


def test_alumno_suspendido_da_403(api):
    api.ref.set({**new_user(api.token, "es", FREE, quota_day()), "state": "suspended",
                 "createdAt": datetime.now(timezone.utc), "updatedAt": datetime.now(timezone.utc),
                 "lastActivityAt": datetime.now(timezone.utc)})
    res = api.cliente.get("/api/v1/me", headers=BEARER)
    assert res.status_code == 403 and res.json()["error"]["code"] == "AUTH_FORBIDDEN"


def test_sesion_revocada_da_401_y_un_inicio_de_sesion_nuevo_pasa(api):
    revocada = datetime.now(timezone.utc) - timedelta(minutes=5)
    api.ref.set({"state": "active", "sessionsRevokedAt": revocada, "lastActivityAt": datetime.now(timezone.utc)})
    api.token["auth_time"] = int((revocada - timedelta(hours=1)).timestamp())
    res = api.cliente.get("/api/v1/me", headers=BEARER)
    assert res.status_code == 401 and res.json()["error"]["code"] == "AUTH_REQUIRED"
    api.token["auth_time"] = int(time.time())  # inició sesión después de la revocación
    assert api.cliente.get("/api/v1/me", headers=BEARER).status_code == 200


def test_last_activity_se_marca_una_vez_al_dia(api):
    hace_dos_dias = datetime.now(timezone.utc) - timedelta(days=2)
    api.ref.set({"state": "active", "lastActivityAt": hace_dos_dias})
    api.cliente.get("/api/v1/me", headers=BEARER)
    marcada = api.ref.get().to_dict()["lastActivityAt"]
    assert marcada > hace_dos_dias + timedelta(days=1), "la primera petición del día actualiza lastActivityAt"
    api.cliente.get("/api/v1/me", headers=BEARER)
    assert api.ref.get().to_dict()["lastActivityAt"] == marcada, "la segunda petición del día no escribe"


def test_me_con_la_forma_del_contrato(api):
    ayer = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()[:10]
    api.ref.set({"name": "Estudiante Demo", "email": "aprueba@demo.cl", "plan": "free", "state": "active",
                 "streak": 3, "locale": "es", "country": "CL", "authProvider": "password",
                 "school": None, "region": None, "age": None, "selectedTests": ["lectora"],
                 "medalWallet": {"bronze": 4, "silver": 1, "gold": 0, "diamond": 0, "platinum": 0},
                 "quota": {"used": 5, "max": 10, "date": ayer, "unlimited": False},
                 "lastActivityAt": datetime.now(timezone.utc)})
    data = api.cliente.get("/api/v1/me", headers=BEARER).json()["data"]
    assert data == {
        "id": f"usr_{UID}", "name": "Estudiante Demo", "email": "aprueba@demo.cl", "plan": "free", "streak": 3,
        "quota": {"used": 0, "max": 10, "unlimited": False},  # otro día: la cuota usada vuelve a 0
        "medals": {"bronze": 4, "silver": 1, "gold": 0, "diamond": 0, "platinum": 0},
        "school": None, "region": None, "age": None, "authProvider": "password", "phone": None,
        "phoneVerified": False, "country": "CL", "language": "es", "gradeId": None, "onboarded": True,
    }


def test_sin_token_da_401_sin_tocar_firestore(api):
    res = api.cliente.get("/api/v1/me")
    assert res.status_code == 401 and not api.ref.get().exists
