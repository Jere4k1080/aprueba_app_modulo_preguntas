import uuid
from contextvars import ContextVar
from datetime import datetime, timezone
from typing import Any

from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse, Response
from starlette.datastructures import MutableHeaders

request_id_var: ContextVar[str | None] = ContextVar("request_id", default=None)


def new_request_id() -> str:
    return f"req_{uuid.uuid4().hex[:12]}"


def meta(extra: dict | None = None) -> dict:
    return {"requestId": request_id_var.get() or new_request_id(),
            # Milisegundos, como toISOString() en Node; isoformat() a secas omite la fracción cuando es cero.
            "timestamp": datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z"),
            **(extra or {})}


def _iso_utc(d: datetime) -> str:
    # Mismo formato que pydantic da a un datetime dentro de un CamelModel: UTC terminado en Z (sección 1.2 de Max).
    return d.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def ok(data: Any, status: int = 200, extra_meta: dict | None = None) -> JSONResponse:
    # custom_encoder alcanza los datetime de dicts y los Timestamp de Firestore; los modelos ya salen así.
    content = jsonable_encoder(data, by_alias=True, custom_encoder={datetime: _iso_utc})
    return JSONResponse(status_code=status, content={"data": content, "error": None, "meta": meta(extra_meta)})


def created(data: Any, extra_meta: dict | None = None) -> JSONResponse:
    return ok(data, 201, extra_meta)


def no_content() -> Response:
    return Response(status_code=204)


class RequestIdMiddleware:
    """Genera el requestId de cada petición, lo deja en request_id_var para meta() y lo
    devuelve en X-Request-Id. Es ASGI puro para que el contextvar siga visible en el
    manejador de errores 500, que corre fuera de los middlewares de usuario."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        rid = new_request_id()
        request_id_var.set(rid)

        async def send_with_id(message):
            if message["type"] == "http.response.start":
                MutableHeaders(scope=message)["X-Request-Id"] = rid
            await send(message)

        await self.app(scope, receive, send_with_id)
