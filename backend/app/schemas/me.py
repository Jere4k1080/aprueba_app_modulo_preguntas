from .common import CamelModel


class QuotaOut(CamelModel):
    used: int
    max: int
    unlimited: bool


class MedalsOut(CamelModel):
    bronze: int
    silver: int
    gold: int
    diamond: int
    platinum: int


class MeOut(CamelModel):
    """Modelo User del contrato de la app (lib/data/models/models.dart), sección 3.1 del diccionario."""
    id: str
    name: str
    email: str
    plan: str
    streak: int
    quota: QuotaOut
    medals: MedalsOut
    school: str | None
    region: str | None
    age: int | None
    auth_provider: str | None
    phone: None = None  # la verificación por SMS está apagada y el teléfono no se guarda (ADR-40)
    phone_verified: bool = False
    country: str | None
    language: str
    grade_id: str | None
    onboarded: bool
