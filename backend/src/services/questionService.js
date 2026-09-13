/**
 * Capa de servicios de preguntas.
 * Implementa la regla de integridad del producto (Decisión ADR-12)
 * y el cálculo de percentil precalculado (Decisión ADR-10).
 */

/**
 * Sanitiza una pregunta antes de emitirla hacia el cliente del estudiante.
 * Proyecta el documento eliminando 'correctAnswer' y 'explanation'
 * para que la clave correcta NUNCA llegue al dispositivo antes de responder.
 *
 * @param {Object} question - Documento original almacenado en Firestore.
 * @returns {Object} Pregunta proyectada y segura para resolución.
 */
function sanitizeQuestion(question) {
  if (!question) return null;

  // Clonación defensiva
  const sanitized = { ...question };

  // Regla de integridad: eliminar la clave de respuesta correcta
  delete sanitized.correctAnswer;

  // La explicación solo se entrega tras responder mediante POST /answer o GET /explanation
  delete sanitized.explanation;

  return sanitized;
}

/**
 * Determina el percentil de rapidez comparando con los umbrales precalculados en O(1).
 *
 * @param {Object} thresholds - Mapa con { p25, p50, p75, p90 } en milisegundos.
 * @param {number} elapsedMs - Tiempo tardado por el alumno.
 * @returns {number} Percentil estimado (1..99).
 */
function calculateCohortPercentile(thresholds, elapsedMs) {
  if (!thresholds || typeof elapsedMs !== 'number') return 50;

  const { p25 = 15000, p50 = 25000, p75 = 45000, p90 = 60000 } = thresholds;

  // A menor tiempo transcurrido, mayor velocidad respecto a la cohorte
  if (elapsedMs <= p25) return 90;
  if (elapsedMs <= p50) return 75;
  if (elapsedMs <= p75) return 50;
  if (elapsedMs <= p90) return 25;
  return 10;
}

module.exports = {
  sanitizeQuestion,
  calculateCohortPercentile,
};
