const jwt = require('jsonwebtoken');
const config = require('../config');
const { AppError } = require('../errors/catalog');

/**
 * Middleware que valida el Access Token JWT en la cabecera Authorization.
 */
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('AUTH_REQUIRED', 'Cabecera Authorization con Bearer token es requerida.'));
  }

  const token = authHeader.substring(7).trim();

  try {
    const decoded = jwt.verify(token, config.jwt.secret);
    req.user = {
      uid: decoded.sub || decoded.uid || decoded.id,
      email: decoded.email,
      role: decoded.role || 'student',
      plan: decoded.plan || 'free',
    };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(new AppError('AUTH_TOKEN_EXPIRED', 'El token de acceso ha expirado.'));
    }
    return next(new AppError('AUTH_REQUIRED', 'Token de acceso inválido o corrupto.'));
  }
}

/**
 * Middleware opcional: si viene token lo valida y adjunta; si no viene, continúa sin usuario.
 */
function optionalAuthMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }
  return authMiddleware(req, res, next);
}

module.exports = {
  authMiddleware,
  optionalAuthMiddleware,
};
