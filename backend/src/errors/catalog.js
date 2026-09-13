/**
 * Catálogo centralizado de códigos de error de la API.
 * Sigue el contrato de respuestas y la especificación de negocio del módulo de preguntas.
 */

class AppError extends Error {
  constructor(code, message, details = null, field = null) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.details = details;
    this.field = field;

    const entry = ErrorCatalog[code];
    this.statusCode = entry ? entry.status : 500;
  }
}

const ErrorCatalog = {
  // ── Diez Errores Estándar HTTP ─────────────────────────────────────────────
  VALIDATION_ERROR: {
    status: 400,
    message: 'Los datos proporcionados son inválidos o están incompletos.',
  },
  AUTH_REQUIRED: {
    status: 401,
    message: 'Autenticación requerida para acceder a este recurso.',
  },
  AUTH_TOKEN_EXPIRED: {
    status: 401,
    message: 'El token de acceso ha expirado.',
  },
  AUTH_FORBIDDEN: {
    status: 403,
    message: 'No tienes los permisos necesarios para realizar esta acción.',
  },
  NOT_FOUND: {
    status: 404,
    message: 'El recurso solicitado no fue encontrado.',
  },
  CONFLICT: {
    status: 409,
    message: 'El recurso ya existe o presenta un conflicto de estado.',
  },
  BUSINESS_RULE_VIOLATION: {
    status: 422,
    message: 'La operación no cumple las reglas del negocio.',
  },
  RATE_LIMITED: {
    status: 429,
    message: 'Has excedido el límite de peticiones. Intenta más tarde.',
  },
  INTERNAL_ERROR: {
    status: 500,
    message: 'Ocurrió un error interno en el servidor.',
  },
  SERVICE_UNAVAILABLE: {
    status: 503,
    message: 'El servicio no se encuentra disponible temporalmente.',
  },

  // ── Errores Específicos del Módulo de Preguntas ────────────────────────────
  QUOTA_BASE_REACHED: {
    status: 422,
    message: 'Has alcanzado la cuota base diaria. Desbloquea más preguntas completando tu perfil.',
  },
  QUOTA_DAILY_LIMIT: {
    status: 422,
    message: 'Has completado todas las preguntas asignadas para hoy. Tu cuota reiniciará a medianoche.',
  },
  NO_QUESTIONS_AVAILABLE: {
    status: 404,
    message: 'No hay más preguntas disponibles en este momento para la prueba o dificultad seleccionada.',
  },
  ALREADY_ANSWERED: {
    status: 409,
    message: 'Esta pregunta ya fue respondida anteriormente.',
  },
  INVALID_OPTION: {
    status: 400,
    message: 'La alternativa seleccionada no es válida para esta pregunta.',
  },
  BONUS_ALREADY_CLAIMED: {
    status: 409,
    message: 'Esta bonificación de cuota ya ha sido solicitada.',
  },
  QUOTA_MAX_REACHED: {
    status: 422,
    message: 'Has alcanzado el límite máximo diario de práctica permitido por tu plan.',
  },
  CORRECTION_ALREADY_OPEN: {
    status: 409,
    message: 'Ya existe una solicitud de recorrección pendiente de revisión para esta pregunta.',
  },
  FORMAT_REQUIRES_PLAN: {
    status: 403,
    message: 'El formato de ensayo o práctica seleccionado requiere un plan de pago activo.',
  },
};

module.exports = {
  AppError,
  ErrorCatalog,
};
