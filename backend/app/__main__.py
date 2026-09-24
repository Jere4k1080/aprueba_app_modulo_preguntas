"""Port de backend/src/server.js: python -m app sirve la API en PORT (4000 por defecto)."""
import uvicorn

from app.core.config import get_settings

uvicorn.run("app.main:app", host="0.0.0.0", port=get_settings().port)
