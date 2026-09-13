const { AppError, ErrorCatalog } = require('../errors/catalog');

/**
 * Middleware central de captura y formato de errores.
 * Garantiza que cualquier excepción viaje formateada bajo el contrato { data: null, error: { ... }, meta: { ... } }.
 */
function errorHandlerMiddleware(err, req, res, next) {
  // Si los encabezados ya fueron enviados, delegar al manejador por defecto de Express
  if (res.headersSent) {
    return next(err);
  }

  let code = 'INTERNAL_ERROR';
  let message = 'Ocurrió un error inesperado en el servidor.';
  let details = null;
  let field = null;
  let statusCode = 500;

  if (err instanceof AppError) {
    code = err.code;
    message = err.message || ErrorCatalog[code]?.message || message;
    details = err.details;
    field = err.field;
    statusCode = err.statusCode;
  } else if (err.name === 'SyntaxError' && err.status === 400 && 'body' in err) {
    code = 'VALIDATION_ERROR';
    message = 'El cuerpo de la petición no contiene un JSON válido.';
    statusCode = 400;
  } else {
    // Log interno en servidor para errores no controlados
    console.error('[Unhandled Error]', err);
    if (process.env.NODE_ENV === 'development') {
      details = { stack: err.stack, originalMessage: err.message };
    }
  }

  return res.sendError(code, message, details, field, statusCode);
}

module.exports = errorHandlerMiddleware;
