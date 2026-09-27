import os
import socket
import time
import urllib.request
from types import SimpleNamespace

import pytest

from app.core.config import Settings, get_settings

# Las pruebas no leen el .env local de quien las corre.
Settings.model_config["env_file"] = None

# Entorno fijo antes de importar app.main, que crea la app a nivel de módulo.
os.environ.update({
    "APP_ENV": "local",
    "FIRESTORE_EMULATOR_HOST": "127.0.0.1:8080",
    "ALLOWED_ORIGINS": "https://app.aprueba.test,http://localhost:3000",
    "ALLOWED_ORIGIN_PATTERN": r"^https://aprueba-pr-[a-z0-9-]+\.vercel\.app$",
})
for name in ("FIREBASE_AUTH_EMULATOR_HOST", "FIREBASE_SERVICE_ACCOUNT_BASE64", "FIREBASE_PROJECT_ID",
             "FIRESTORE_EMULATOR_PROJECT_ID", "SEED_ALLOW_REMOTE", "SEED_DEMO_UID", "SEED_DEMO_NEW_UID"):
    os.environ.pop(name, None)

# UID ficticios con el largo de un UID de Firebase (28 caracteres).
UIDS_DEMO = {"demo": "demoUid000000000000000000001", "nuevo": "demoUid000000000000000000002"}


@pytest.fixture(autouse=True)
def _settings_frescos():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def emulador_activo() -> bool:
    try:
        socket.create_connection(("127.0.0.1", 8080), timeout=0.5).close()
        return True
    except OSError:
        return False


@pytest.fixture
def banco(monkeypatch):
    """App contra un proyecto del emulador con el seed cargado y un token de aprueba@demo.cl. Se salta si el
    emulador está apagado."""
    if not emulador_activo():
        pytest.skip("emulador de Firestore apagado en 127.0.0.1:8080")
    from fastapi.testclient import TestClient
    from firebase_admin import auth as firebase_auth
    from google.cloud import firestore

    import app.db.firestore as firestore_db
    from app import seed
    from app.main import create_app
    from app.services.users import quota_day

    proyecto = "demo-pytest-banco"
    monkeypatch.setenv("FIRESTORE_EMULATOR_PROJECT_ID", proyecto)
    monkeypatch.setattr(firestore_db, "_client", None)
    get_settings.cache_clear()
    token = {"uid": UIDS_DEMO["demo"], "sub": UIDS_DEMO["demo"], "email": "aprueba@demo.cl",
             "firebase": {"sign_in_provider": "password"}, "auth_time": int(time.time())}
    monkeypatch.setattr(firebase_auth, "verify_id_token", lambda _t, **_k: dict(token))
    db = firestore.Client(project=proyecto)
    lote = db.batch()
    for ruta, datos in seed.build_documents(UIDS_DEMO, quota_day()):
        lote.set(db.document(ruta), datos)
    lote.commit()
    usuario = f"users/usr_{UIDS_DEMO['demo']}"
    try:
        app = create_app()
        # Un solo event loop para todas las peticiones: el cliente asíncrono de Firestore queda atado al primero.
        with TestClient(app) as cliente:
            yield SimpleNamespace(app=app, cliente=cliente, db=db, token=token,
                                  user=db.document(usuario), estado=db.document(f"{usuario}/state/practice"))
    finally:
        pedido = urllib.request.Request(
            f"http://127.0.0.1:8080/emulator/v1/projects/{proyecto}/databases/(default)/documents", method="DELETE")
        urllib.request.urlopen(pedido, timeout=10).close()
