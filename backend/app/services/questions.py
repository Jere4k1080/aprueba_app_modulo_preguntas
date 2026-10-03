"""Capa de servicios de preguntas: regla de integridad (ADR-12), percentil de cohorte (ADR-87) y explicación breve."""
import re

# Tramos de questions.stats.elapsedBuckets (ADR-63). Cada tramo cuenta las respuestas con tiempo menor
# que su límite en segundos y mayor o igual que el límite anterior; gte300 no tiene límite superior.
ELAPSED_BUCKETS = (("lt10", 10), ("lt20", 20), ("lt30", 30), ("lt45", 45), ("lt60", 60),
                   ("lt90", 90), ("lt120", 120), ("lt180", 180), ("lt300", 300), ("gte300", None))
# Respuestas previas que necesita una pregunta para entregar percentil; con menos, cohortPercentile es null.
MIN_COHORT = 5
SHORT_EXPLANATION_MAX = 200


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


def cohort_percentile(buckets: dict | None, elapsed_ms: int) -> int | None:
    """Porcentaje de las respuestas anteriores a la misma pregunta que fueron más lentas (ADR-87). Sale del
    histograma de antes de sumar esta respuesta: cuentan los tramos más lentos y la mitad del propio, porque el
    histograma no ordena las respuestas de un mismo tramo. None con menos de MIN_COHORT respuestas previas."""
    conteos = [int((buckets or {}).get(tramo) or 0) for tramo, _ in ELAPSED_BUCKETS]
    total = sum(conteos)
    if total < MIN_COHORT:
        return None
    i = [tramo for tramo, _ in ELAPSED_BUCKETS].index(elapsed_bucket(elapsed_ms))
    # 100 × (más lentas + mitad del tramo) / total, redondeado con las mitades hacia arriba y sin flotantes.
    numerador, denominador = 200 * sum(conteos[i + 1:]) + 100 * conteos[i], 2 * total
    return (2 * numerador + denominador) // (2 * denominador)


def short_explanation(explanation: str | None) -> str:
    """Explicación breve de la pantalla Resultado (ADR-86): la primera línea de la explicación, sin el número de
    paso y cortada en una palabra si pasa de SHORT_EXPLANATION_MAX caracteres. La completa llega con HU-05."""
    linea = next((l.strip() for l in (explanation or "").splitlines() if l.strip()), "")
    linea = re.sub(r"^\d+\.\s*", "", linea)
    if len(linea) <= SHORT_EXPLANATION_MAX:
        return linea
    return linea[:SHORT_EXPLANATION_MAX].rsplit(" ", 1)[0].rstrip(",;:") + "…"
