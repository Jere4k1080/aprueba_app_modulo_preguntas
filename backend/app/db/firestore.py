import base64
import json
import os
import re

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
    corrections = "corrections"
    users = "users"
    plans = "plans"
    features = "features"
    medal_transactions = "medalTransactions"
    # Subcolecciones de users/{usr_<UID>}
    answers = "answers"
    skill_mastery = "skillMastery"
    state = "state"


# La administración valida los IDs de users con este patrón (GET y PATCH /admin/users/{id}).
USER_ID_PATTERN = re.compile(r"^usr_[A-Za-z0-9_]{1,36}$")


def user_doc_id(uid: str) -> str:
    """ID del documento de users para un UID de Firebase: el formato usr_* de la administración (ADR-58)."""
    return f"usr_{uid}"


_client: AsyncClient | None = None
# Proyecto donde la app inicia sesión. Con el emulador de Firestore es el proyecto por defecto de
# Firebase Admin, porque es la audiencia que exige verify_id_token a los tokens de la app (ADR-49).
APP_PROJECT = "aprueba-app-modulo-preguntas"
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
        # Proyecto demo- del emulador, el mismo que muestra su interfaz; FIREBASE_PROJECT_ID es solo para tokens.
        return AsyncClient(project=settings.firestore_emulator_project_id)
    if settings.firebase_service_account_base64:
        info = _service_account_info(settings)
        # Una variable definida pero vacía cuenta como ausente en Settings; la librería, en cambio,
        # entraría en modo emulador con host vacío.
        os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
        credentials = service_account.Credentials.from_service_account_info(info)
        return AsyncClient(project=info.get("project_id"), credentials=credentials)
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
            "projectId": settings.firebase_project_id or APP_PROJECT, "httpTimeout": HTTP_TIMEOUT})
    if settings.firebase_service_account_base64:
        info = _service_account_info(settings)
        return firebase_admin.initialize_app(firebase_credentials.Certificate(info), {
            "projectId": settings.firebase_project_id or info.get("project_id"), "httpTimeout": HTTP_TIMEOUT})
    raise RuntimeError(MISSING_CONFIG)
