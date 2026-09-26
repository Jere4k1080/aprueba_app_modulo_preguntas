"""Alta de alumnos en users (ADR-66): el documento nuevo sale solo de aquí.

El seed crea con new_user() las cuentas de demostración, y la creación en la primera petición
autenticada, que llega con los endpoints, usa la misma función. Así hay una sola forma de crear un
alumno."""
from google.cloud.firestore import SERVER_TIMESTAMP

from app.core.config import ADDRESS_BONUS, QUOTA_CAP, SCHOOL_BONUS

TIERS = ("bronze", "silver", "gold", "diamond", "platinum")


def quota_max(plan: dict, bonus_school: bool = False, bonus_address: bool = False) -> int:
    """Límite diario de preguntas (ADR-64): la base del plan más los bonos, con tope. 0 si el plan es ilimitado."""
    q_day = plan["limits"]["qDay"]
    if q_day == 0:
        return 0
    return min(q_day + SCHOOL_BONUS * bonus_school + ADDRESS_BONUS * bonus_address, QUOTA_CAP)


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
