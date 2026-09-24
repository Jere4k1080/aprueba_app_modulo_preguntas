from typing import Annotated

from fastapi import Depends, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from google.cloud.firestore import AsyncClient

from ..db.firestore import get_db, get_firebase_app
from .errors import ApiError

# HTTPBearer entrega None si falta la cabecera, si el esquema no es Bearer o si el token viene vacío.
bearer = HTTPBearer(auto_error=False)
Credentials = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]


async def get_current_user(cred: Credentials) -> dict:
    """Valida el token de Firebase Auth que la app envía en Authorization."""
    if cred is None:
        raise ApiError(401, "AUTH_REQUIRED")
    firebase_app = get_firebase_app()  # fuera del try: un error de configuración no se disfraza de 401
    try:
        # verify_id_token es bloqueante: puede bajar los certificados públicos de Google.
        # check_revoked=False evita una consulta a Firebase Auth por petición; un token revocado
        # sigue sirviendo hasta que expira, como máximo una hora. clock_skew_seconds tolera un
        # reloj del servidor algunos segundos atrasado respecto de Google.
        claims = await run_in_threadpool(auth.verify_id_token, cred.credentials,
                                         app=firebase_app, check_revoked=False, clock_skew_seconds=5)
    except auth.ExpiredIdTokenError:  # hereda de InvalidIdTokenError, por eso va primero
        raise ApiError(401, "AUTH_TOKEN_EXPIRED")
    except auth.CertificateFetchError:
        raise ApiError(503, "SERVICE_UNAVAILABLE")
    # firebase_admin 7.7.0 deja escapar TypeError con algunos tokens mal formados (kid que no es
    # texto, claim d que no es objeto). Un ValueError, en cambio, es de configuración y termina en 500.
    except (auth.InvalidIdTokenError, TypeError):
        raise ApiError(401, "AUTH_REQUIRED")
    # role y plan salen de custom claims mientras la forma de users sigue en pausa. Sin ellos,
    # student y free.
    return {
        "uid": claims["uid"],
        "email": claims.get("email"),
        "role": claims.get("role") or "student",
        "plan": claims.get("plan") or "free",
    }


async def get_optional_user(request: Request, cred: Credentials) -> dict | None:
    # Sin cabecera es anónimo; una cabecera presente pero inválida da el mismo 401.
    return None if "authorization" not in request.headers else await get_current_user(cred)


DB = Annotated[AsyncClient, Depends(get_db)]
CurrentUser = Annotated[dict, Depends(get_current_user)]
OptionalUser = Annotated[dict | None, Depends(get_optional_user)]
