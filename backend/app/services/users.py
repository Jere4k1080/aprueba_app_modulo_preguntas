"""Alta de alumnos en users (ADR-66) y alumno de cada petición (ADR-71).

El seed crea con new_user() las cuentas de demostración, y la creación en la primera petición
autenticada usa la misma función. Así hay una sola forma de crear un alumno."""
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from google.cloud import firestore
from google.cloud.firestore import SERVER_TIMESTAMP

from app.core.config import ADDRESS_BONUS, QUOTA_CAP, SCHOOL_BONUS, get_settings
from app.core.errors import ApiError
from app.db.firestore import COL, user_doc_id

TIERS = ("bronze", "silver", "gold", "diamond", "platinum")


def quota_max(plan: dict, bonus_school: bool = False, bonus_address: bool = False) -> int:
    """Límite diario de preguntas (ADR-64): la base del plan más los bonos, con tope. 0 si el plan es ilimitado."""
    q_day = plan["limits"]["qDay"]
    if q_day == 0:
        return 0
    return min(q_day + SCHOOL_BONUS * bonus_school + ADDRESS_BONUS * bonus_address, QUOTA_CAP)


def quota_day(now: datetime | None = None) -> str:
    """Día de la cuota, YYYY-MM-DD, en QUOTA_RESET_TIMEZONE y contado desde QUOTA_RESET_HOUR_LOCAL (ADR-11)."""
    settings = get_settings()
    local = (now or datetime.now(timezone.utc)).astimezone(ZoneInfo(settings.quota_reset_timezone))
    return (local - timedelta(hours=settings.quota_reset_hour_local)).date().isoformat()


def new_user(claims: dict, locale: str, free_plan: dict, today: str) -> dict:
    """Documento con que el alta crea users/usr_<UID>. Lleva los campos que usa la administración y los
    del módulo, nada de otros módulos. claims es el ID token de Firebase ya verificado, locale sale de
    Accept-Language y today es la fecha de la cuota en el huso de QUOTA_RESET_TIMEZONE."""
    email = claims.get("email") or ""
    name = claims.get("name") or email.split("@")[0]
    provider = (claims.get("firebase") or {}).get("sign_in_provider", "")
    return {
        # Administración: sección 2.8 y ficha de usuario de la sección 7
        "name": name, "nameLower": name.lower(), "email": email, "emailLower": email.lower(),
        "plan": "free", "state": "active", "country": "CL", "subscriptionId": None,
        "medalWallet": dict.fromkeys(TIERS, 0), "badgesTotal": 0,
        "authProvider": provider.removesuffix(".com"),  # google.com pasa a google, como en el modelo de junio
        "school": None, "region": None, "age": None, "streak": 0, "locale": locale,
        # La consola ordena por nameLower, lastActivityAt, badgesTotal y createdAt, y actualiza updatedAt.
        "createdAt": SERVER_TIMESTAMP, "updatedAt": SERVER_TIMESTAMP, "lastActivityAt": SERVER_TIMESTAMP,
        # Módulo: campos del modelo de junio
        "quota": {"used": 0, "max": quota_max(free_plan), "date": today, "bonusSchool": False,
                  "bonusAddress": False, "unlimited": free_plan["limits"]["qDay"] == 0},
        "selectedTests": [], "practiceFormat": "random", "difficulty": "d1",
    }


async def current_student(db, claims: dict, locale: str) -> dict:
    """Alumno del token en una sola lectura de users/usr_<UID> (ADR-71). Si el documento no existe lo
    crea (ADR-66); si existe, rechaza una sesión revocada o un alumno suspendido (ADR-65) y marca la
    actividad en la primera petición del día (ADR-68). Devuelve el documento con su id."""
    ref = db.collection(COL.users).document(user_doc_id(claims["uid"]))
    snap = await ref.get()
    if not snap.exists:
        return {"id": ref.id, **await create_user(db, ref, claims, locale)}
    user = snap.to_dict()
    # La revocación va antes que la suspensión: al suspender, la consola escribe las dos cosas, y con el
    # 401 la app renueva el token, recibe otro 401 porque auth_time no cambia y cierra la sesión (ADR-40).
    revoked = user.get("sessionsRevokedAt")
    if revoked and datetime.fromtimestamp(claims.get("auth_time", 0), timezone.utc) < revoked:
        raise ApiError(401, "AUTH_REQUIRED")
    if user.get("state") == "suspended":
        raise ApiError(403, "AUTH_FORBIDDEN")
    last = user.get("lastActivityAt")
    if not isinstance(last, datetime) or quota_day(last) != quota_day():
        await ref.update({"lastActivityAt": SERVER_TIMESTAMP})
    return {"id": ref.id, **user}


async def create_user(db, ref, claims: dict, locale: str) -> dict:
    """Crea el alumno con new_user() en una transacción que nunca pisa un documento existente. Solo corre
    en la primera petición de cada alumno, así que la segunda lectura de users y la de plans/free no se
    repiten."""
    free = await db.collection(COL.plans).document("free").get()
    if not free.exists:
        raise RuntimeError("Falta plans/free: sin ese documento el alta no tiene base de cuota (ADR-64).")
    doc = new_user(claims, locale, free.to_dict(), quota_day())

    @firestore.async_transactional
    async def crear(tx):
        snap = await ref.get(transaction=tx)
        if snap.exists:  # otra petición lo creó entre la lectura y la transacción
            return snap.to_dict()
        tx.create(ref, doc)
        return doc

    return await crear(db.transaction())
