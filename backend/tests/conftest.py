import os

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
             "FIRESTORE_EMULATOR_PROJECT_ID", "SEED_ALLOW_REMOTE"):
    os.environ.pop(name, None)


@pytest.fixture(autouse=True)
def _settings_frescos():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()
