const crypto = require('crypto');

/**
 * Middleware que garantiza el contrato de respuestas estándar:
 * {
 *   "data": { ... } | null,
 *   "error": { "code", "message", "details", "field" } | null,
 *   "meta": { "requestId", "timestamp", ... }
 * }
 */
function envelopeMiddleware(req, res, next) {
  const requestId = req.headers['x-request-id'] || `req_${crypto.randomUUID()}`;
  res.setHeader('x-request-id', requestId);

  // Helper para respuestas exitosas
  res.sendData = function(data, statusCode = 200, extraMeta = {}) {
    return res.status(statusCode).json({
      data: data !== undefined ? data : null,
      error: null,
      meta: {
        requestId,
        timestamp: new Date().toISOString(),
        ...extraMeta,
      },
    });
  };

  // Helper para respuestas con error controlado
  res.sendError = function(code, message, details = null, field = null, statusCode = 400) {
    return res.status(statusCode).json({
      data: null,
      error: {
        code,
        message,
        details,
        field,
      },
      meta: {
        requestId,
        timestamp: new Date().toISOString(),
      },
    });
  };

  next();
}

module.exports = envelopeMiddleware;
