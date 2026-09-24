import json
import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.datastructures import Headers
from starlette.exceptions import HTTPException as StarletteHTTPException

from .envelope import meta, request_id_var
from .i18n import resolve_locale

logger = logging.getLogger("app.errors")


class ApiError(Exception):
    def __init__(self, status: int, code: str, *, field: str | None = None,
                 details: list[dict] | None = None, message: str | None = None, **fmt):
        super().__init__(code)
        # La firma de Max pide el status aparte; esto evita que un código del catálogo salga con otro status.
        if ERROR_STATUS.get(code, status) != status:
            raise ValueError(f"{code} va con status {ERROR_STATUS[code]}, no con {status}.")
        self.status, self.code, self.field = status, code, field
        self.details, self.message, self.fmt = details or [], message, fmt


# Catálogo de mensajes: code -> {es, en}. Los diez estándar llevan el texto de la
# especificación de Alloxentric, salvo AUTH_TOKEN_EXPIRED, que remite a Firebase Auth (ADR-40);
# los del módulo, el texto de backend/src/errors/catalog.js.
# METHOD_NOT_ALLOWED y PAYLOAD_TOO_LARGE son propios de este backend y no están en la especificación.
MESSAGES: dict[str, dict[str, str]] = {
    "VALIDATION_ERROR": {"es": "Uno o más campos no superan la validación.", "en": "One or more fields failed validation."},
    "AUTH_REQUIRED": {"es": "Falta el token de acceso o es inválido.", "en": "Missing or invalid access token."},
    "AUTH_TOKEN_EXPIRED": {"es": "El token de acceso expiró. La app debe pedir uno nuevo a Firebase y reintentar.",
                           "en": "The access token expired. The app must request a new one from Firebase and retry."},
    "AUTH_FORBIDDEN": {"es": "Tu rol no autoriza esta acción.", "en": "Your role does not allow this action."},
    "NOT_FOUND": {"es": "El recurso solicitado no existe.", "en": "The requested resource does not exist."},
    "METHOD_NOT_ALLOWED": {"es": "El método HTTP no está permitido en esta ruta.", "en": "The HTTP method is not allowed on this route."},
    "CONFLICT": {"es": "La operación choca con el estado actual del recurso.", "en": "The operation conflicts with the current state."},
    "PAYLOAD_TOO_LARGE": {"es": "El cuerpo de la petición supera el tamaño máximo permitido.", "en": "The request body exceeds the maximum allowed size."},
    "BUSINESS_RULE_VIOLATION": {"es": "La solicitud infringe una regla de negocio.", "en": "The request violates a business rule."},
    "RATE_LIMITED": {"es": "Demasiadas peticiones; reintenta en unos segundos.", "en": "Too many requests; retry shortly."},
    "INTERNAL_ERROR": {"es": "Error inesperado del servidor.", "en": "Unexpected server error."},
    "SERVICE_UNAVAILABLE": {"es": "Un servicio dependiente no está disponible.", "en": "A dependent service is unavailable."},
    # Módulo de preguntas
    "QUOTA_BASE_REACHED": {
        "es": "Has alcanzado la cuota base diaria. Desbloquea más preguntas completando tu perfil.",
        "en": "You have reached your daily base quota. Unlock more questions by completing your profile."},
    "QUOTA_DAILY_LIMIT": {
        "es": "Has completado todas las preguntas asignadas para hoy. Tu cuota reiniciará a medianoche.",
        "en": "You have completed all the questions assigned for today. Your quota will reset at midnight."},
    "NO_QUESTIONS_AVAILABLE": {
        "es": "No hay más preguntas disponibles en este momento para la prueba o dificultad seleccionada.",
        "en": "There are no more questions available right now for the selected test or difficulty."},
    "ALREADY_ANSWERED": {
        "es": "Esta pregunta ya fue respondida anteriormente.",
        "en": "This question has already been answered."},
    "INVALID_OPTION": {
        "es": "La alternativa seleccionada no es válida para esta pregunta.",
        "en": "The selected option is not valid for this question."},
    "BONUS_ALREADY_CLAIMED": {
        "es": "Esta bonificación de cuota ya ha sido solicitada.",
        "en": "This quota bonus has already been claimed."},
    "QUOTA_MAX_REACHED": {
        "es": "Has alcanzado el límite máximo diario de práctica permitido por tu plan.",
        "en": "You have reached the maximum daily practice limit allowed by your plan."},
    "CORRECTION_ALREADY_OPEN": {
        "es": "Ya existe una solicitud de recorrección pendiente de revisión para esta pregunta.",
        "en": "A correction request for this question is already pending review."},
    "FORMAT_REQUIRES_PLAN": {
        "es": "El formato de ensayo o práctica seleccionado requiere un plan de pago activo.",
        "en": "The selected mock exam or practice format requires an active paid plan."},
}

# Los estándar van primero: al traducir un status HTTP a código gana el genérico.
ERROR_STATUS: dict[str, int] = {
    "VALIDATION_ERROR": 400, "AUTH_REQUIRED": 401, "AUTH_TOKEN_EXPIRED": 401, "AUTH_FORBIDDEN": 403,
    "NOT_FOUND": 404, "METHOD_NOT_ALLOWED": 405, "CONFLICT": 409, "PAYLOAD_TOO_LARGE": 413, "BUSINESS_RULE_VIOLATION": 422,
    "RATE_LIMITED": 429, "INTERNAL_ERROR": 500, "SERVICE_UNAVAILABLE": 503,
    "QUOTA_BASE_REACHED": 422, "QUOTA_DAILY_LIMIT": 422, "NO_QUESTIONS_AVAILABLE": 404,
    "ALREADY_ANSWERED": 409, "INVALID_OPTION": 400, "BONUS_ALREADY_CLAIMED": 409,
    "QUOTA_MAX_REACHED": 422, "CORRECTION_ALREADY_OPEN": 409, "FORMAT_REQUIRES_PLAN": 422,
}

INVALID_JSON = {"es": "El cuerpo de la petición no contiene un JSON válido.",
                "en": "The request body is not valid JSON."}


def _msg(code: str, locale: str, **fmt) -> str:
    tpl = MESSAGES.get(code, {}).get(locale) or MESSAGES.get(code, {}).get("es") or code
    return tpl.format(**fmt) if fmt else tpl


def _envelope(status: int, code: str, message: str, field=None, details=None, extra_meta=None, headers=None):
    m = meta(extra_meta)
    return JSONResponse(status_code=status, headers={**(headers or {}), "X-Request-Id": m["requestId"]}, content={
        "data": None,
        "error": {"code": code, "message": message, "field": field, "details": details or []},
        "meta": m})


def _locale(request: Request) -> str:
    return resolve_locale(request.headers.get("accept-language"))


async def _unhandled(request: Request, exc: Exception):
    logger.error("Error no controlado en %s %s [%s]", request.method, request.url.path,
                 request_id_var.get(), exc_info=exc)
    return _envelope(500, "INTERNAL_ERROR", _msg("INTERNAL_ERROR", _locale(request)))


def install_error_handlers(app: FastAPI) -> None:
    async def api_error(request: Request, exc: ApiError):
        extra = {"retryAfter": exc.fmt["retry_after"]} if "retry_after" in exc.fmt else None
        return _envelope(exc.status, exc.code, exc.message or _msg(exc.code, _locale(request), **exc.fmt),
                         exc.field, exc.details, extra)

    async def validation(request: Request, exc: RequestValidationError):
        # Un error sobre el cuerpo completo deja field en null, no en texto vacío.
        details = [{"field": ".".join(str(x) for x in e["loc"] if x not in ("body", "query", "path", "header", "cookie")) or None,
                    "message": e["msg"], "type": e["type"]} for e in exc.errors()]
        field = details[0]["field"] if details else None
        return _envelope(400, "VALIDATION_ERROR", _msg("VALIDATION_ERROR", _locale(request)), field, details)

    async def http_error(request: Request, exc: StarletteHTTPException):
        code = next((c for c, s in ERROR_STATUS.items() if s == exc.status_code), "INTERNAL_ERROR")
        return _envelope(exc.status_code, code, _msg(code, _locale(request)), headers=exc.headers)

    app.add_exception_handler(ApiError, api_error)
    app.add_exception_handler(RequestValidationError, validation)
    app.add_exception_handler(StarletteHTTPException, http_error)
    # Respaldo para lo que falle en RequestIdMiddleware o en CORS; el resto lo atiende UnhandledErrorMiddleware.
    app.add_exception_handler(Exception, _unhandled)


class UnhandledErrorMiddleware:
    """Responde 500 INTERNAL_ERROR dentro de CORS. Starlette atiende Exception en su
    middleware más externo y esa respuesta sale sin Access-Control-Allow-Origin, así que
    el navegador no deja leer el envelope. En Express el errorHandler corría después de cors()."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        started = False

        async def tracking_send(message):
            nonlocal started
            started = started or message["type"] == "http.response.start"
            await send(message)

        try:
            await self.app(scope, receive, tracking_send)
        except Exception as exc:
            if started:
                raise
            response = await _unhandled(Request(scope), exc)
            await response(scope, receive, send)


def _reject_constant(name: str):
    raise ValueError(name)


MAX_JSON_BODY = 100 * 1024  # el límite por defecto de express.json()


class JsonBodyMiddleware:
    """Revisa antes del enrutamiento el cuerpo de un POST, PUT o PATCH con Content-Type
    application/json. De express.json() toma el modo estricto (objeto o arreglo) y el tope
    de 100 kB. En Node, ese error llegaba al errorHandler antes que res.sendError y salía
    como 500 en HTML con la traza; aquí un JSON inválido da 400 VALIDATION_ERROR y un
    cuerpo sobre el tope da 413 PAYLOAD_TOO_LARGE, ambos con el envelope. El cuerpo leído
    se reentrega intacto."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["method"] not in ("POST", "PUT", "PATCH"):
            return await self.app(scope, receive, send)
        headers = Headers(scope=scope)
        if headers.get("content-type", "").split(";")[0].strip().lower() != "application/json":
            return await self.app(scope, receive, send)
        loc = resolve_locale(headers.get("accept-language"))

        chunks, size, more = [], 0, True
        while more:
            message = await receive()
            if message["type"] != "http.request":
                return  # el cliente se desconectó
            chunks.append(message.get("body", b""))
            size += len(chunks[-1])
            if size > MAX_JSON_BODY:
                return await _envelope(413, "PAYLOAD_TOO_LARGE", _msg("PAYLOAD_TOO_LARGE", loc))(scope, receive, send)
            more = message.get("more_body", False)
        body = b"".join(chunks)

        if body:
            try:
                if body.removeprefix(b"\xef\xbb\xbf").lstrip(b" \t\n\r")[:1] not in (b"{", b"["):
                    raise ValueError("modo estricto de express.json()")
                json.loads(body, parse_constant=_reject_constant)  # JSON.parse rechaza NaN e Infinity
            except (ValueError, RecursionError):  # RecursionError: anidamiento más hondo que el límite de Python
                return await _envelope(400, "VALIDATION_ERROR", INVALID_JSON[loc], details=[
                    {"field": None, "message": "JSON decode error", "type": "json_invalid"}])(scope, receive, send)

        replayed = False

        async def replay():
            nonlocal replayed
            if replayed:
                return await receive()
            replayed = True
            return {"type": "http.request", "body": body, "more_body": False}

        await self.app(scope, replay, send)
