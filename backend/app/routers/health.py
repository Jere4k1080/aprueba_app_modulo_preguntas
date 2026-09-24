import time

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..core.config import get_settings
from ..core.envelope import ok
from ..schemas.health import HealthOut, HealthResponse

router = APIRouter(tags=["health"])
_started = time.monotonic()


@router.head("/health", include_in_schema=False)  # Express atiende HEAD en toda ruta GET
@router.get("/health", response_model=HealthResponse)
async def health() -> JSONResponse:
    return ok(HealthOut(
        status="ok",
        service="aprueba-questions-backend",
        version="1.0.0",
        uptime_seconds=int(time.monotonic() - _started),
        environment=get_settings().app_env,
    ))
