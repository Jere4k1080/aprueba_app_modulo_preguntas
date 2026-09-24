import os
from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict

# Valor de desarrollo, el mismo que usaba el backend Node. Nunca se acepta en producción.
DEV_JWT_SECRET = "dev_jwt_secret_change_in_production_min_32_chars"

# Regla de negocio 1. Fijas en el código como en Node: no se leen del entorno.
BASE_QUOTA = 10
SCHOOL_BONUS = 5
ADDRESS_BONUS = 5


class Settings(BaseSettings):
    # env_ignore_empty: una variable vacía cuenta como no definida, igual que `||` en Node.
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", env_ignore_empty=True)

    port: int = 4000
    app_env: Literal["local", "staging", "production"] = "local"

    jwt_secret: str = ""
    jwt_expires_in: str = "15m"
    refresh_token_expires_in: str = "30d"

    # Reinicio de la cuota configurable por entorno (ADR-11)
    quota_reset_hour_local: int = 0
    quota_reset_timezone: str = "America/Santiago"

    firebase_project_id: str | None = None
    firestore_emulator_host: str | None = None
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
        if self.app_env == "production" and not self.jwt_secret.strip():
            raise RuntimeError("JWT_SECRET es obligatorio en producción.")
        self.jwt_secret = self.jwt_secret or DEV_JWT_SECRET

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
