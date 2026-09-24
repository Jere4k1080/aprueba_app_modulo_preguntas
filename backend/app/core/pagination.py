import base64
import json
from datetime import datetime
from typing import Annotated

from fastapi import Query
from google.cloud import firestore
from google.cloud.firestore_v1 import AsyncQuery

from .errors import ApiError


def encode_cursor(value, doc_id: str) -> str:
    # Firestore ordena primero por tipo: una fecha enviada como texto queda después de toda fecha
    # y start_after pierde o repite páginas. Por eso el cursor recuerda que era una fecha.
    data = {"v": value.isoformat(), "t": "ts", "id": doc_id} if isinstance(value, datetime) else {"v": value, "id": doc_id}
    return base64.urlsafe_b64encode(json.dumps(data, default=str).encode()).decode().rstrip("=")


def decode_cursor(cursor: str | None) -> dict | None:
    if not cursor:
        return None
    try:
        data = json.loads(base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)))
        doc_id = data["id"]
        if "v" not in data or not isinstance(doc_id, str) or not doc_id or "/" in doc_id:
            raise ValueError
        if data.get("t") == "ts":
            data["v"] = datetime.fromisoformat(data["v"])
    except Exception:
        raise ApiError(400, "VALIDATION_ERROR", field="cursor",
                       details=[{"field": "cursor", "message": "Invalid cursor", "type": "cursor_invalid"}]) from None
    return data


class PageParams:
    def __init__(self, limit: Annotated[int, Query(ge=1, le=100)] = 20, cursor: str | None = Query(default=None)):
        self.limit, self.cursor = limit, cursor


async def paginate(q: AsyncQuery, page: PageParams, sort_field: str, desc: bool = False, serializer=lambda d: d):
    """Aplica orden estable, cursor y limit+1 para saber si hay más. Devuelve (items, meta)."""
    cur = decode_cursor(page.cursor)  # antes de count(): un cursor corrupto no gasta una consulta
    total = (await q.count().get())[0][0].value
    direction = firestore.Query.DESCENDING if desc else firestore.Query.ASCENDING
    q = q.order_by(sort_field, direction=direction).order_by("__name__", direction=direction)
    if cur:
        q = q.start_after({sort_field: cur["v"], "__name__": q._parent.document(cur["id"])})
    docs = [d async for d in q.limit(page.limit + 1).stream()]
    has_more = len(docs) > page.limit
    docs = docs[: page.limit]
    items = [serializer({"id": d.id, **d.to_dict()}) for d in docs]
    next_cursor = encode_cursor(docs[-1].get(sort_field), docs[-1].id) if has_more and docs else None
    return items, {"pagination": {"limit": page.limit, "nextCursor": next_cursor, "total": total}}
