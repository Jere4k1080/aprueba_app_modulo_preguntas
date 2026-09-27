from fastapi import APIRouter
from fastapi.responses import JSONResponse
from google.cloud.firestore import SERVER_TIMESTAMP

from ..core.deps import DB, Student
from ..core.envelope import ok
from ..core.errors import ApiError
from ..db.firestore import COL
from ..schemas.me import MedalsOut, MeOut, QuotaOut
from ..schemas.practice import PreferencesIn, PreferencesOut
from ..services.practice import active_tests, has_questions, mock_mode_allowed
from ..services.users import TIERS, quota_day

router = APIRouter(tags=["me"])


def me_out(user: dict) -> MeOut:
    """Perfil del alumno desde su documento de users (diccionario, sección 3.1)."""
    quota = user.get("quota") or {}
    wallet = user.get("medalWallet") or {}
    return MeOut(
        id=user["id"],
        name=user.get("name") or "",
        email=user.get("email") or "",
        plan=user.get("plan") or "free",
        streak=user.get("streak") or 0,
        # Si cambió el día, la cuota usada ya es 0 aunque el reinicio lo escriba recién GET /practice/next.
        quota=QuotaOut(used=quota.get("used", 0) if quota.get("date") == quota_day() else 0,
                       max=quota.get("max", 0), unlimited=bool(quota.get("unlimited"))),
        medals=MedalsOut(**{tier: wallet.get(tier, 0) for tier in TIERS}),
        school=user.get("school"),
        region=user.get("region"),
        age=user.get("age"),
        auth_provider=user.get("authProvider"),
        country=user.get("country"),
        language=user.get("locale") or "es",
        grade_id=user.get("gradeId"),
        onboarded=bool(user.get("selectedTests")),
    )


def preferences_out(user: dict) -> PreferencesOut:
    """Preferences de la app desde users: practiceFormat se llama format y locale, language (ADR-28)."""
    return PreferencesOut(
        selected_tests=user.get("selectedTests") or [],
        format=user.get("practiceFormat") or "random",
        difficulty=user.get("difficulty") or "d1",
        country=user.get("country"),
        language=user.get("locale") or "es",
        grade_id=user.get("gradeId"),
        onboarded=bool(user.get("selectedTests")),
    )


@router.get("/me")
async def me(student: Student) -> JSONResponse:
    return ok(me_out(student))


@router.get("/me/preferences")
async def get_preferences(student: Student) -> JSONResponse:
    return ok(preferences_out(student))


@router.put("/me/preferences")
async def put_preferences(body: PreferencesIn, student: Student, db: DB) -> JSONResponse:
    """Guarda las preferencias de práctica. selectedTests solo acepta pruebas activas con preguntas, y
    facsim exige que el plan incluya mock_mode (ADR-70)."""
    selected = list(dict.fromkeys(body.selected_tests))  # sin repetidas, en el orden en que llegaron
    tests = await active_tests(db)
    invalid = [t for t in selected if t not in tests or not has_questions(tests[t])]
    if invalid:
        raise ApiError(400, "VALIDATION_ERROR", field="selectedTests",
                       details=[{"field": "selectedTests", "message": f"The test {t} has no questions.",
                                 "type": "test_without_questions"} for t in invalid])
    if body.format == "facsim" and not await mock_mode_allowed(db, student.get("plan") or "free"):
        raise ApiError(422, "FORMAT_REQUIRES_PLAN", field="format")
    update = {"selectedTests": selected, "practiceFormat": body.format, "difficulty": body.difficulty,
              "updatedAt": SERVER_TIMESTAMP}
    # country, language y gradeId son opcionales en la app: solo se escriben si llegan.
    for campo, valor in (("country", body.country), ("locale", body.language), ("gradeId", body.grade_id)):
        if valor is not None:
            update[campo] = valor
    await db.collection(COL.users).document(student["id"]).update(update)
    return ok(preferences_out({**student, **update}))
