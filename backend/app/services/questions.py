"""Capa de servicios de preguntas: regla de integridad (ADR-12) y percentil de cohorte.

calculate_cohort_percentile usa los umbrales de ADR-10, que ADR-63 reemplaza por el histograma de
questions.stats.elapsedBuckets; el cálculo con el histograma llega en la iteración 4."""

# Tramos de questions.stats.elapsedBuckets (ADR-63). Cada tramo cuenta las respuestas con tiempo menor
# que su límite en segundos y mayor o igual que el límite anterior; gte300 no tiene límite superior.
ELAPSED_BUCKETS = (("lt10", 10), ("lt20", 20), ("lt30", 30), ("lt45", 45), ("lt60", 60),
                   ("lt90", 90), ("lt120", 120), ("lt180", 180), ("lt300", 300), ("gte300", None))


def elapsed_bucket(elapsed_ms: int) -> str:
    """Nombre del tramo del histograma que corresponde a un tiempo de respuesta."""
    for tramo, limite in ELAPSED_BUCKETS:
        if limite is None or elapsed_ms < limite * 1000:
            return tramo


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
