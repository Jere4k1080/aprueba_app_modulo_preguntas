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

  bool get isQuotaExhausted =>
      code == 'QUOTA_EXHAUSTED' || code == 'PRACTICE_QUOTA_EXHAUSTED';
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
