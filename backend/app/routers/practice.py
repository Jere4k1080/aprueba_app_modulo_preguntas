from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..core.deps import DB, Student
from ..core.envelope import ok
from ..core.errors import ApiError
from ..services.practice import check_quota, fresh_quota, load_plan, pending_or_next, question_out, quota_meta

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
