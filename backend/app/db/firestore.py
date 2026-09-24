import base64
import json
import os

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


def _create_client(settings: Settings) -> AsyncClient:
    if settings.firestore_emulator_host:
        # La librería detecta el emulador solo por variable de entorno; si el valor vino de .env hay que exportarlo.
        os.environ["FIRESTORE_EMULATOR_HOST"] = settings.firestore_emulator_host
        return AsyncClient(project=settings.firebase_project_id or "aprueba-dev")
    if settings.firebase_service_account_base64:
        try:
            # Tolerante como Buffer.from(x, 'base64') de Node: acepta el valor sin relleno y el alfabeto URL seguro.
            info = json.loads(base64.b64decode(settings.firebase_service_account_base64 + "==", altchars=b"-_"))
            if not isinstance(info, dict):
                raise ValueError
        except ValueError:
            raise RuntimeError("FIREBASE_SERVICE_ACCOUNT_BASE64 no contiene un JSON válido.") from None
        # Una variable definida pero vacía cuenta como ausente en Settings; la librería, en cambio,
        # entraría en modo emulador con host vacío.
        os.environ.pop("FIRESTORE_EMULATOR_HOST", None)
        credentials = service_account.Credentials.from_service_account_info(info)
        return AsyncClient(project=settings.firebase_project_id or info.get("project_id"), credentials=credentials)
    raise RuntimeError("Configura FIRESTORE_EMULATOR_HOST o FIREBASE_SERVICE_ACCOUNT_BASE64.")


def get_db() -> AsyncClient:
    global _client
    if _client is None:
        _client = _create_client(get_settings())
    return _client
