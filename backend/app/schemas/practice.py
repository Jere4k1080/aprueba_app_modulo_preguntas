from typing import Literal

from pydantic import Field

from .common import CamelModel


class TestOut(CamelModel):
    """TestInfo de la app. hasQuestions es approvedStock > 0 (ADR-72)."""
    id: str
    label: str
    color: str
    has_questions: bool


class PreferencesIn(CamelModel):
    """Cuerpo de PUT /me/preferences: los campos que envía Preferences.toJson() de la app."""
    # Vacía da NO_TESTS_SELECTED en la ruta, como pide el contrato (ADR-72).
    selected_tests: list[str]
    format: Literal["random", "facsim"]
    difficulty: Literal["d1", "d2", "d3", "d4"]
    country: str | None = Field(default=None, pattern=r"^[A-Z]{2}$")
    language: Literal["es", "en"] | None = None
    grade_id: str | None = Field(default=None, min_length=1, max_length=40)


class AnswerIn(CamelModel):
    """Cuerpo de POST /questions/{id}/answer. sessionId y elapsedMs se aceptan porque los manda la app y los lista
    el contrato, pero no se usan: el tiempo lo mide el servidor desde deliveredAt (T-28, ADR-86). La letra se
    valida contra las alternativas de la pregunta, con INVALID_OPTION."""
    selected: str
    session_id: str | None = None
    elapsed_ms: int | None = None


class PreferencesOut(CamelModel):
    selected_tests: list[str]
    format: str
    difficulty: str
    country: str | None
    language: str
    grade_id: str | None
    onboarded: bool
