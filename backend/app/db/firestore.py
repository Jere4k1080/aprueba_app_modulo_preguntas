import base64
import json
import os

import firebase_admin
from firebase_admin import credentials as firebase_credentials
from google.auth.credentials import AnonymousCredentials
from google.cloud.firestore import AsyncClient
from google.oauth2 import service_account

from app.core.config import Settings, get_settings


class COL:
    """Nombres de colecciones. Los esquemas viven en seed/README.md y docs/diccionario_de_datos.md."""
    tests = "tests"
    skills = "skills"
    questions = "questions"
    answers = "answers"
    corrections = "corrections"
    users = "users"
    # Subcolecciones de users/{uid}
    medal_ledger = "medalLedger"
    state = "state"


_client: AsyncClient | None = None
EMULATOR_PROJECT = "aprueba-dev"
MISSING_CONFIG = "Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64."
HTTP_TIMEOUT = 10  # segundos para bajar los certificados de Google; Dio corta a los 20


def _service_account_info(settings: Settings) -> dict:
    try:
        # Tolerante como Buffer.from(x, 'base64') de Node: acepta el valor sin relleno y el alfabeto URL seguro.
        info = json.loads(base64.b64decode(settings.firebase_service_account_base64 + "==", altchars=b"-_"))
        if not isinstance(info, dict):
            raise ValueError
    except ValueError:
        raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_BASE64 no contiene un JSON válido.") from None
    return info


def _create_client(settings: Settings) -> AsyncClient:
    if settings.firestore_emulator_host:
        # La librería detecta el emulador solo por variable de entorno; si el valor vino de .env hay que exportarlo.
        os.environ["FIRESTORE_EMULATOR_HOST"] = settings.firestore_emulator_host
        return AsyncClient(project=settings.firebase_project_id or EMULATOR_PROJECT)
    if settings.firebase_service_account_base64:
        info = _service_account_info(settings)
        # Una variable definida pero vacía cuenta como ausente en Settings; la librería, en cambio,
        # entraría en modo emulador con host vacío.
        os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
        credentials = service_account.Credentials.from_service_account_info(info)
        return AsyncClient(project=settings.firebase_project_id or info.get("project_id"), credentials=credentials)
    raise RuntimeError(MISSING_CONFIG)


def get_db() -> AsyncClient:
    global _client
    if _client is None:
        _client = _create_client(get_settings())
    return _client


def get_firebase_app() -> firebase_admin.App:
    """Firebase Admin, solo para verificar los tokens de Firebase Auth. Sale de la misma
    configuración que Firestore. Se crea una vez por proceso, aunque create_app() corra varias."""
    try:
        return firebase_admin.get_app()
    except ValueError:
        pass
    settings = get_settings()
    if os.environ.get("FIREBASE_AUTH_EMULATOR_HOST") and (
            settings.app_env != "local" or not settings.firestore_emulator_host):
        # Con esa variable firebase_admin acepta tokens sin firma.
        raise RuntimeError("FIREBASE_AUTH_EMULATOR_HOST solo se admite con APP_ENV=local y FIRESTORE_EMULATOR_HOST.")
    # Sin httpTimeout la descarga de certificados espera hasta 120 s. Al vencer da el 503 de deps.py.
    if settings.firestore_emulator_host:
        # Sin credencial, firebase_admin cargaría las credenciales predeterminadas de Google al
        # primer verify_id_token. Verificar un token solo usa los certificados públicos.
        return firebase_admin.initialize_app(AnonymousCredentials(), {
            "projectId": settings.firebase_project_id or EMULATOR_PROJECT, "httpTimeout": HTTP_TIMEOUT})
    if settings.firebase_service_account_base64:
        info = _service_account_info(settings)
        return firebase_admin.initialize_app(firebase_credentials.Certificate(info), {
            "projectId": settings.firebase_project_id or info.get("project_id"), "httpTimeout": HTTP_TIMEOUT})
    raise RuntimeError(MISSING_CONFIG)
