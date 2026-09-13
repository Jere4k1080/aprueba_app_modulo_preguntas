import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../local/database.dart';
import '../models/models.dart';

/// Catálogo educativo servido por el backend: países, grados/pruebas por país y
/// asignaturas por grado. Sustituye al catálogo hardcodeado del cliente, que
/// queda solo como respaldo cuando la API no responde (ver catalogProviders).
class CatalogRepository {
  CatalogRepository(this._api, this._db);
  final ApiClient _api;
  final AppDatabase _db;

  Future<List<Country>> countries({String? lang}) async {
    final res = await _api.get<List<Country>>(
      Endpoints.countries,
      query: {if (lang != null) 'lang': lang},
      skipAuth: true,
      parse: (d) => (d as List)
          .map((e) => Country.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data;
  }

  Future<List<GradeGroup>> grades(String countryCode, {String? lang}) async {
    final res = await _api.get<List<GradeGroup>>(
      Endpoints.countryGrades(countryCode),
      query: {if (lang != null) 'lang': lang},
      skipAuth: true,
      parse: (d) => (d as List)
          .map((e) => GradeGroup.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data;
  }

  /// Asignaturas del grado. Sin `gradeId` devuelve el catálogo de pruebas del
  /// usuario autenticado (el backend usa su grado guardado).
  Future<List<TestInfo>> subjects({String? gradeId, String? lang}) async {
    final res = await _api.get<List<TestInfo>>(
      Endpoints.tests,
      query: {
        if (gradeId != null) 'gradeId': gradeId,
        if (lang != null) 'lang': lang,
      },
      parse: (d) => (d as List)
          .map((e) => TestInfo.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    await _db.writeCache('tests', res.data.map((t) => t.toJson()).toList());
    return res.data;
  }
}
