from typing import Literal

from .common import CamelModel


class HealthOut(CamelModel):
    status: Literal["ok"]
    service: str
    version: str
    uptime_seconds: int
    environment: str


class HealthResponse(CamelModel):
    """Solo documenta en OpenAPI el envelope que arma ok(); la ruta devuelve JSONResponse."""
    data: HealthOut
    error: None
    meta: dict
