import os
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

# Regla de negocio 1. Fijas en el código como en Node: no se leen del entorno.
BASE_QUOTA = 10
SCHOOL_BONUS = 5
ADDRESS_BONUS = 5


class Settings(BaseSettings):
    # env_ignore_empty: una variable vacía cuenta como no definida, igual que `||` en Node.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", env_ignore_empty=True)

    port: int = 4000
    app_env: Literal["local", "staging", "production"] = "local"

    # Reinicio de la cuota configurable por entorno (ADR-11)
    quota_reset_hour_local: int = 0
    quota_reset_timezone: str = "America/Santiago"

    # Solo para validar tokens de Firebase Auth: es la audiencia que exige verify_id_token (ADR-49).
    firebase_project_id: str | None = None
    firestore_emulator_host: str | None = None
    # Proyecto de Firestore dentro del emulador. Con demo- nunca toca recursos reales (ADR-49).
    firestore_emulator_project_id: str = "demo-aprueba"
    firebase_service_account_base64: str | None = None

    allowed_origins: str = ""
    allowed_origin_pattern: str | None = None

    seed_allow_remote: bool = False

    def __init__(self, **values):
        # Fuera de un validador de pydantic: su ValidationError vuelca los valores de
        # entrada, incluida la cuenta de servicio, en el log de arranque.
        super().__init__(**values)
        # En Vercel (VERCEL) o Cloud Run (K_SERVICE) el entorno se declara: sin APP_ENV no arranca
        # como local con la documentación abierta.
        if "app_env" not in self.model_fields_set and (os.environ.get("VERCEL") or os.environ.get("K_SERVICE")):
            raise RuntimeError("APP_ENV es obligatorio en Vercel y en Cloud Run.")

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
