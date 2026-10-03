from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..core.deps import DB, Student
from ..core.envelope import ok
from ..core.errors import ApiError
from ..schemas.practice import AnswerIn
from ..services.answers import register_answer
from ..services.practice import (check_quota, fresh_quota, load_plan, pending_or_next, question_fields, question_out,
                                 quota_meta, student_question)

router = APIRouter(tags=["practice"])


@router.get("/practice/next")
async def practice_next(student: Student, db: DB) -> JSONResponse:
    """Siguiente pregunta. Reinicia y revisa la cuota sin descontarla, y entrega la pendiente o una nueva
    (ADR-72). La respuesta correcta nunca va en esta ruta."""
    plan = await load_plan(db, student.get("plan") or "free")
    quota = await fresh_quota(db, student, plan)
    check_quota(quota, plan)
    tests = student.get("selectedTests") or []
    if not tests:
        # ADR-29: con field selectedTests la app lleva al alumno a elegir sus pruebas.
        raise ApiError(404, "NO_QUESTIONS_AVAILABLE", field="selectedTests",
                       details=[{"field": "selectedTests", "message": "No tests selected.", "type": "NO_TESTS_SELECTED"}])
    question = await pending_or_next(db, student, tests)
    if question is None:
        raise ApiError(404, "NO_QUESTIONS_AVAILABLE")
    return ok(question_out(question, quota), extra_meta=quota_meta(quota))


@router.get("/questions/{question_id}")
async def get_question(question_id: str, student: Student, db: DB) -> JSONResponse:
    """Pregunta por ID, sin correctAnswer ni explanation (T-20). Solo la pendiente del alumno o una que ya
    respondió; cualquier otra da NOT_FOUND sin confirmar si existe (ADR-85)."""
    question = await student_question(db, student, question_id)
    if question is None:
        raise ApiError(404, "NOT_FOUND")
    return ok(question_fields(question))


@router.post("/questions/{question_id}/answer")
async def answer_question(question_id: str, body: AnswerIn, student: Student, db: DB) -> JSONResponse:
    """Registra la respuesta a la pendiente (HU-03). Es la única ruta que entrega correctAnswer, después de
    responder; la explicación detallada llega con HU-05 (ADR-86)."""
    return ok(await register_answer(db, student, question_id, body.selected))
