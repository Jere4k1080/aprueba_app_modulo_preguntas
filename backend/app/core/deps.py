from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from google.cloud.firestore import AsyncClient

from ..db.firestore import get_db
from .config import get_settings
from .errors import ApiError

# Port de backend/src/middleware/auth.js. Ningún router lo usa todavía; la entrega C
# lo reemplaza por la verificación de tokens de Firebase Auth.
bearer = HTTPBearer(auto_error=False)
Credentials = Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]


async def get_current_user(cred: Credentials) -> dict:
    if cred is None:
        raise ApiError(401, "AUTH_REQUIRED")
    try:
        # jsonwebtoken.verify no revisaba aud, sub, jti ni iat futuro; PyJWT sí, así que se apagan para igualarlo.
        claims = jwt.decode(cred.credentials, get_settings().jwt_secret, algorithms=["HS256"], options={
            "verify_aud": False, "verify_sub": False, "verify_jti": False, "verify_iat": False})
    except jwt.ExpiredSignatureError:
        raise ApiError(401, "AUTH_TOKEN_EXPIRED")
    except jwt.InvalidTokenError:
        raise ApiError(401, "AUTH_REQUIRED")
    return {
        "uid": claims.get("sub") or claims.get("uid") or claims.get("id"),
        "email": claims.get("email"),
        "role": claims.get("role") or "student",
        "plan": claims.get("plan") or "free",
    }


async def get_optional_user(cred: Credentials) -> dict | None:
    return None if cred is None else await get_current_user(cred)


DB = Annotated[AsyncClient, Depends(get_db)]
CurrentUser = Annotated[dict, Depends(get_current_user)]
OptionalUser = Annotated[dict | None, Depends(get_optional_user)]
