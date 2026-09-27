from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..core.deps import DB, Student
from ..core.envelope import ok
from ..schemas.practice import TestOut
from ..services.practice import active_tests, has_questions

router = APIRouter(tags=["catalog"])


@router.get("/tests")
async def list_tests(student: Student, db: DB) -> JSONResponse:
    """Pruebas activas en su orden de despliegue, con hasQuestions (ADR-72 y ADR-73)."""
    tests = await active_tests(db)
    return ok([TestOut(id=test_id, label=t.get("label", test_id), color=t.get("color", "#1A365D"),
                       has_questions=has_questions(t)) for test_id, t in tests.items()])
