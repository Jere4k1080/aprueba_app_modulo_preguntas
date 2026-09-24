"""Capa de servicios de preguntas: regla de integridad (ADR-12) y percentil precalculado (ADR-10)."""


def sanitize_question(question: dict | None) -> dict | None:
    """Copia la pregunta sin correctAnswer ni explanation. La alternativa correcta nunca llega al
    cliente antes de responder; la explicación se entrega tras responder."""
    if question is None:
        return None
    sanitized = dict(question)
    sanitized.pop("correctAnswer", None)
    sanitized.pop("explanation", None)
    return sanitized


def _es_numero(x) -> bool:
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def calculate_cohort_percentile(thresholds: dict | None, elapsed_ms) -> int:
    """Percentil de rapidez contra los umbrales {p25, p50, p75, p90} en milisegundos.
    Un umbral ausente o no numérico toma su valor por defecto, para que un documento mal
    cargado no termine en 500."""
    if not isinstance(thresholds, dict) or not _es_numero(elapsed_ms):
        return 50
    for percentil, campo, por_defecto in ((90, "p25", 15000), (75, "p50", 25000), (50, "p75", 45000), (25, "p90", 60000)):
        umbral = thresholds.get(campo)
        if elapsed_ms <= (umbral if _es_numero(umbral) else por_defecto):
            return percentil
    return 10
