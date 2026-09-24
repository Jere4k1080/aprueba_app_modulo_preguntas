import re

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .core.config import get_settings
from .core.envelope import RequestIdMiddleware
from .core.errors import JsonBodyMiddleware, UnhandledErrorMiddleware, install_error_handlers
from .db.firestore import get_db
from .routers import health


def create_app() -> FastAPI:
    settings = get_settings()  # falla en producción sin JWT_SECRET
    get_db()  # falla al iniciar si no hay emulador ni cuenta de servicio
    # Starlette compila el patrón recién en la primera petición; así un patrón inválido corta el arranque, como en Node.
    re.compile(settings.allowed_origin_pattern or "")

    docs = settings.app_env != "production"
    app = FastAPI(title="Aprueba API del módulo de preguntas", version="1.0.0",
                  docs_url="/api/v1/docs" if docs else None,
                  openapi_url="/api/v1/openapi.json" if docs else None,
                  redoc_url=None)

    # add_middleware apila hacia afuera: queda RequestId > CORS > UnhandledError > JsonBody > rutas.
    app.add_middleware(JsonBodyMiddleware)
    app.add_middleware(UnhandledErrorMiddleware)
    app.add_middleware(CORSMiddleware,
                       allow_origins=settings.cors_origins,
                       allow_origin_regex=settings.allowed_origin_pattern,
                       allow_credentials=False,  # ADR-19: el token viaja en Authorization, sin cookies
                       allow_methods=["*"],
                       allow_headers=["*"])
    app.add_middleware(RequestIdMiddleware)
    install_error_handlers(app)

    app.include_router(health.router, prefix="/api/v1")
    # Los trece servicios del módulo (/practice/next, /questions/{id}, ...) llegan en iteraciones siguientes.
    return app


app = create_app()
