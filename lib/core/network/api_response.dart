/// Envelope común { data, error, meta } de la API de Aprueba.
class ApiResponse<T> {
  ApiResponse({required this.data, this.meta});
  final T data;
  final Map<String, dynamic>? meta;

  /// Información de paginación basada en cursor (meta.pagination).
  String? get nextCursor =>
      (meta?['pagination'] as Map?)?['nextCursor'] as String?;
  int? get total => (meta?['pagination'] as Map?)?['total'] as int?;
}
