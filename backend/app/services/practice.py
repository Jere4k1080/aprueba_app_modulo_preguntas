"""Cuota diaria y siguiente pregunta (ADR-09, ADR-29, ADR-64, ADR-70, ADR-72 y ADR-73)."""
import random

from google.cloud.firestore import FieldFilter

from app.core.config import QUOTA_CAP
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
        raise RuntimeError(f"Falta plans/{plan_id}: sin ese documento no hay base de cuota (ADR-64).")
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


def check_quota(quota: dict) -> None:
    """Regla de negocio 1: los planes ilimitados no tienen tope. Al llegar al máximo, QUOTA_BASE_REACHED si
    un bono sin reclamar todavía sumaría preguntas, para que la app lleve al desbloqueo, y QUOTA_DAILY_LIMIT
    si no. Con max en QUOTA_CAP ningún bono suma, como pasaría con qDay 20 (ADR-73)."""
    if quota.get("unlimited") or quota.get("used", 0) < quota.get("max", 0):
        return
    if quota.get("max", 0) < QUOTA_CAP and (not quota.get("bonusSchool") or not quota.get("bonusAddress")):
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


async def pending_or_next(db, user: dict, tests: list[str]) -> dict | None:
    """La pregunta pendiente o una nueva (ADR-72). La entregada queda en state/practice.lastQuestionId y se
    vuelve a entregar mientras no esté en answeredQuestionIds, así pedir otra no recorre el banco sin gastar
    cuota. Solo la transacción de responder, de la iteración 5, la saca de pendiente."""
    state_ref = db.collection(COL.users).document(user["id"]).collection(COL.state).document("practice")
    state = (await state_ref.get()).to_dict() or {}
    answered = set(state.get("answeredQuestionIds") or [])
    pending = state.get("lastQuestionId")
    if pending and pending not in answered:
        snap = await db.collection(COL.questions).document(pending).get()
        if snap.exists and (snap.to_dict() or {}).get("status") == "published":
            return {"id": snap.id, **snap.to_dict()}
        # Si la pendiente dejó de estar publicada, se elige otra (ADR-73).
    question = await pick_question(db, tests, user.get("difficulty") or "d1", answered)
    if question is not None:
        # ponytail: sin transacción, dos pedidos simultáneos pueden elegir preguntas distintas y queda la
        # última como pendiente. La respuesta de la iteración 5 puede exigir que sea la pendiente.
        await state_ref.set({"lastQuestionId": question["id"]}, merge=True)
    return question


def question_out(question: dict, quota: dict) -> dict:
    """Pregunta para el alumno: pasa por sanitize_question() y lleva el progreso del día (ADR-72)."""
    limpia = sanitize_question(question)
    out = {campo: limpia.get(campo) for campo in QUESTION_FIELDS}
    out["progress"] = {"current": quota.get("used", 0) + 1,
                       "total": None if quota.get("unlimited") else quota.get("max", 0)}
    return out


def quota_meta(quota: dict) -> dict:
    return {"quota": {"used": quota.get("used", 0), "max": quota.get("max", 0), "unlimited": bool(quota.get("unlimited"))}}
