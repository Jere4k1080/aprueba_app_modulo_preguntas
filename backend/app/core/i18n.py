from typing import Literal

from fastapi import Header

Locale = Literal["es", "en"]


def resolve_locale(header: str | None) -> Locale:
    if not header:
        return "es"
    for part in header.split(","):
        tag = part.split(";")[0].strip().lower()
        if tag.startswith("en"):
            return "en"
        if tag.startswith("es"):
            return "es"
    return "es"


async def get_locale(accept_language: str | None = Header(default=None)) -> Locale:
    return resolve_locale(accept_language)


def t(obj: dict | str | None, locale: Locale) -> str:
    """Devuelve el texto localizado de un campo {es, en} almacenado en Firestore."""
    if isinstance(obj, dict):
        return obj.get(locale) or obj.get("es") or ""
    return obj or ""
