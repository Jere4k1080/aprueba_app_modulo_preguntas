/// Error de negocio devuelto por el backend dentro del envelope `error`.
/// Ver el catálogo de errores estándar en Aprueba_API_Backend.
class ApiException implements Exception {
  ApiException({
    required this.code,
    required this.message,
    this.field,
    this.statusCode,
    this.details = const [],
  });

  final String code;
  final String message;
  final String? field;
  final int? statusCode;
  final List<dynamic> details;

  /// Sin respuesta del servidor. Es el único error que la app muestra como
  /// "sin conexión": un 404 o un 401 traen respuesta.
  bool get isNetwork => code == 'NETWORK_ERROR';

  /// Cuota base alcanzada con un bono que todavía suma: lleva a la pantalla de
  /// desbloqueo, no a un error (regla de negocio 8).
  bool get isQuotaBaseReached => code == 'QUOTA_BASE_REACHED';

  /// Límite diario alcanzado: seguir hoy requiere un plan de pago.
  bool get isQuotaExhausted => code == 'QUOTA_DAILY_LIMIT';

  /// No quedan preguntas para las pruebas y la dificultad elegidas.
  bool get isNoQuestions => code == 'NO_QUESTIONS_AVAILABLE';

  /// El alumno no tiene pruebas elegidas (ADR-29): la app lo invita a elegirlas.
  bool get needsTests => isNoQuestions && field == 'selectedTests';

  bool get isAuthRequired => code == 'AUTH_REQUIRED' || statusCode == 401;
  bool get isForbidden => code == 'AUTH_FORBIDDEN' || statusCode == 403;

  factory ApiException.network() => ApiException(
        code: 'NETWORK_ERROR',
        message: 'Sin conexión. Mostrando datos guardados si existen.',
      );

  factory ApiException.fromMap(Map<String, dynamic> error, {int? statusCode}) {
    return ApiException(
      code: (error['code'] ?? 'UNKNOWN') as String,
      message: (error['message'] ?? 'Error desconocido') as String,
      field: error['field'] as String?,
      details: (error['details'] as List?) ?? const [],
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
