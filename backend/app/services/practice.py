"""Cuota diaria, siguiente pregunta y pregunta por ID (ADR-09, ADR-29, ADR-70, ADR-72, ADR-73, ADR-76, ADR-84
y ADR-85)."""
import random
from datetime import datetime, timezone

from google.api_core import exceptions
from google.cloud.firestore import FieldFilter

from app.core.envelope import iso_ms
from app.core.errors import ApiError
from app.db.firestore import COL
from app.services.questions import sanitize_question
from app.services.users import quota_day, quota_max

# Campos de la pregunta que ve el alumno: los de GET /practice/next en el contrato, más skillId, que la app usa.
QUESTION_FIELDS = ("id", "testId", "axis", "skillId", "difficulty", "statement", "options")


async def active_tests(db) -> dict[str, dict]:
    """Pruebas con active en true, por ID y en su orden de despliegue. Son cinco documentos: se ordenan en
    memoria para no pedir un índice compuesto de active y order."""
    docs = [(d.id, d.to_dict()) async for d in db.collection(COL.tests).stream()]
    return dict(sorted(((i, t) for i, t in docs if t.get("active", True)), key=lambda it: it[1].get("order", 0)))


def has_questions(test: dict) -> bool:
    """hasQuestions del contrato: approvedStock > 0, el contador que mantiene el generador (ADR-72)."""
    return (test.get("approvedStock") or 0) > 0


async def load_plan(db, plan_id: str) -> dict:
    plan = await db.collection(COL.plans).document(plan_id).get()
    if not plan.exists:
        raise RuntimeError(f"Falta plans/{plan_id}: sin ese documento no hay tope de cuota (ADR-76).")
    return plan.to_dict()


async def mock_mode_allowed(db, plan_id: str) -> bool:
    """El facsímil se permite si el plan incluye la funcionalidad con key mock_mode (ADR-70). Si el catálogo
    no la tiene, se sigue la regla 5 anterior: plan de pago."""
    features = [f async for f in db.collection(COL.features)
                .where(filter=FieldFilter("key", "==", "mock_mode")).limit(1).stream()]
    if not features:
        return plan_id != "free"
    return features[0].id in ((await load_plan(db, plan_id)).get("features") or [])


async def fresh_quota(db, user: dict, plan: dict) -> dict:
    """Cuota del día. Si quota.date no es hoy la reinicia y la guarda, con el máximo recalculado desde el
    plan por si la consola lo cambió (ADR-73). No descuenta: eso lo hace la respuesta (ADR-72)."""
    quota = dict(user.get("quota") or {})
    today = quota_day()
    if quota.get("date") == today:
        return quota
    quota.update(used=0, date=today, unlimited=plan["limits"]["qDay"] == 0,
                 max=quota_max(plan, quota.get("bonusSchool", False), quota.get("bonusAddress", False)))
    await db.collection(COL.users).document(user["id"]).update({"quota": quota})
    return quota


def check_quota(quota: dict, plan: dict) -> None:
    """Regla de negocio 1: los planes ilimitados no tienen tope. Al llegar al máximo, QUOTA_BASE_REACHED si
    un bono sin reclamar todavía sumaría preguntas, para que la app lleve al desbloqueo, y QUOTA_DAILY_LIMIT
    si no. Un bono suma mientras el máximo esté bajo el tope qDay del plan (ADR-76)."""
    if quota.get("unlimited") or quota.get("used", 0) < quota.get("max", 0):
        return
    bono_libre = not quota.get("bonusSchool") or not quota.get("bonusAddress")
    if bono_libre and quota.get("max", 0) < plan["limits"]["qDay"]:
        raise ApiError(422, "QUOTA_BASE_REACHED")
    raise ApiError(422, "QUOTA_DAILY_LIMIT")


async def pick_question(db, tests: list[str], difficulty: str, answered: set[str], r: float | None = None) -> dict | None:
    """Pregunta published al azar entre las pruebas elegidas y la dificultad preferida, sin las ya respondidas.
    Parte desde un randomKey al azar y, si no encuentra, da la vuelta desde 0 (ADR-73)."""
    r = random.random() if r is None else r
    base = (db.collection(COL.questions)
            .where(filter=FieldFilter("testId", "in", tests))
            .where(filter=FieldFilter("status", "==", "published"))
            .where(filter=FieldFilter("difficulty", "==", difficulty)))
    # ponytail: las respondidas se descartan en memoria (ADR-09), así que cada tramo lee hasta
    # len(answered) + 1 documentos. Con miles de respondidas conviene guardar un cursor por prueba.
    for tramo in (FieldFilter("randomKey", ">=", r), FieldFilter("randomKey", "<", r)):
        # get() y no stream(): salir a mitad de un stream deja la llamada de gRPC abierta.
        for doc in await base.where(filter=tramo).order_by("randomKey").limit(len(answered) + 1).get():
            if doc.id not in answered:
                return {"id": doc.id, **doc.to_dict()}
    return None


def practice_state(db, user_id: str):
    """users/usr_<UID>/state/practice: respondidas, pendiente y hora de entrega (ADR-09, ADR-72 y ADR-84)."""
    return db.collection(COL.users).document(user_id).collection(COL.state).document("practice")


def pending_id(state: dict) -> str | None:
    """La pendiente es lastQuestionId mientras no figure entre las respondidas (ADR-72)."""
    pending = state.get("lastQuestionId")
    return pending if pending and pending not in (state.get("answeredQuestionIds") or []) else None


async def _published(db, question_id: str) -> dict | None:
    snap = await db.collection(COL.questions).document(question_id).get()
    data = snap.to_dict() if snap.exists else None
    return {"id": snap.id, **data} if data and data.get("status") == "published" else None


PENDING_ATTEMPTS = 5


async def pending_or_next(db, user: dict, tests: list[str]) -> dict | None:
    """La pregunta pendiente o una nueva (ADR-72). La entregada queda en lastQuestionId con deliveredAt, la hora
    de la API desde la que se mide el tiempo de respuesta (T-28). Solo la transacción de responder la saca de
    pendiente.

    T-25 y ADR-84: la pendiente se fija con una escritura condicionada a que state/practice no haya cambiado
    desde que se leyó (o a que no exista). Si otra solicitud escribió antes, se relee y se entrega la suya, así
    las solicitudes simultáneas reciben la misma pregunta. Una transacción del SDK, que bloquea el documento
    leído, dejaba a cinco solicitudes simultáneas esperándose entre sí hasta agotar sus intentos."""
    state_ref = practice_state(db, user["id"])
    for _ in range(PENDING_ATTEMPTS):
        snap = await state_ref.get()
        state = snap.to_dict() or {}
        pending = pending_id(state)
        # Si la pendiente dejó de estar publicada, se elige otra (ADR-73).
        question = await _published(db, pending) if pending else None
        if question and state.get("deliveredAt"):
            return {**question, "deliveredAt": state["deliveredAt"]}
        if question is None:
            question = await pick_question(db, tests, user.get("difficulty") or "d1",
                                           set(state.get("answeredQuestionIds") or []))
            if question is None:
                return None
        # Una pendiente guardada antes de deliveredAt empieza a contar ahora.
        cambios = {"lastQuestionId": question["id"], "deliveredAt": datetime.now(timezone.utc)}
        try:
            if snap.exists:
                await state_ref.update(cambios, option=db.write_option(last_update_time=snap.update_time))
            else:
                await state_ref.create(cambios)
        except (exceptions.FailedPrecondition, exceptions.Conflict):
            continue  # otra solicitud fijó la pendiente entre la lectura y la escritura
        return {**question, "deliveredAt": cambios["deliveredAt"]}
    raise RuntimeError("No se pudo fijar la pregunta pendiente: state/practice cambió en cada intento.")


async def student_question(db, user: dict, question_id: str) -> dict | None:
    """Pregunta que el alumno puede pedir por ID (T-20, ADR-85): su pendiente, con su deliveredAt, o una que ya
    respondió, con deliveredAt en None. Cualquier otra da None, exista o no: entregar cualquier pregunta por ID
    permitiría recorrer el banco sin gastar cuota (RNF-04)."""
    state = (await practice_state(db, user["id"]).get()).to_dict() or {}
    if question_id in (state.get("answeredQuestionIds") or []):
        delivered = None
    elif question_id == pending_id(state):
        delivered = state.get("deliveredAt")
    else:
        return None
    snap = await db.collection(COL.questions).document(question_id).get()
    return {"id": snap.id, **snap.to_dict(), "deliveredAt": delivered} if snap.exists else None


def question_fields(question: dict) -> dict:
    """Pregunta para el alumno: pasa por sanitize_question() y se proyecta a QUESTION_FIELDS, más deliveredAt."""
    limpia = sanitize_question(question)
    out = {campo: limpia.get(campo) for campo in QUESTION_FIELDS}
    delivered = question.get("deliveredAt")
    out["deliveredAt"] = iso_ms(delivered) if delivered else None
    return out


def question_out(question: dict, quota: dict) -> dict:
    """Respuesta de GET /practice/next: la pregunta con su hora de entrega y el progreso del día (ADR-72)."""
    out = question_fields(question)
    out["progress"] = {"current": quota.get("used", 0) + 1,
                       "total": None if quota.get("unlimited") else quota.get("max", 0)}
    return out


def quota_meta(quota: dict) -> dict:
    return {"quota": {"used": quota.get("used", 0), "max": quota.get("max", 0), "unlimited": bool(quota.get("unlimited"))}}
