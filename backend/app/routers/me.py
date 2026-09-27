from fastapi import APIRouter
from fastapi.responses import JSONResponse

from ..core.deps import Student
from ..core.envelope import ok
from ..schemas.me import MedalsOut, MeOut, QuotaOut
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


@router.get("/me")
async def me(student: Student) -> JSONResponse:
    return ok(me_out(student))
