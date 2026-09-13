import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/endpoints.dart';
import '../local/database.dart';
import '../models/models.dart';

/// Perfil, cuota, progreso y preferencias de práctica.
class ProfileRepository {
  ProfileRepository(this._api, this._db);
  final ApiClient _api;
  final AppDatabase _db;

  Future<User> me({bool forceRefresh = false}) async {
    try {
      final res = await _api.get(Endpoints.me,
          parse: (d) => User.fromJson((d as Map).cast<String, dynamic>()));
      await _db.writeCache('me', res.data.toJson());
      return res.data;
    } on ApiException catch (e) {
      if (e.code == 'NETWORK_ERROR') {
        final cached = await _db.readCache('me');
        if (cached is Map) return User.fromJson(cached.cast<String, dynamic>());
      }
      rethrow;
    }
  }

  Future<User> updateProfile({String? school, int? age, String? region}) async {
    final res = await _api.patch(Endpoints.me,
        body: {if (school != null) 'school': school, if (age != null) 'age': age, if (region != null) 'region': region},
        parse: (d) => d);
    return me(forceRefresh: true);
  }

  Future<void> deleteAccount(String password) =>
      _api.delete(Endpoints.me, body: {'password': password});

  Future<QuotaState> quota() async {
    final res = await _api.get(Endpoints.meQuota,
        parse: (d) => QuotaState.fromJson((d as Map).cast<String, dynamic>()));
    await _db.writeCache('quota', d2map(res.data));
    return res.data;
  }

  Future<QuotaState> unlockQuota({required String type, String? school, int? age, String? region}) async {
    final res = await _api.post(Endpoints.meQuotaUnlock,
        body: {'type': type, if (school != null) 'school': school, if (age != null) 'age': age, if (region != null) 'region': region},
        parse: (d) => QuotaState.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<List<ProgressItem>> progress() async {
    try {
      List<dynamic> raw = const [];
      final res = await _api.get<List<ProgressItem>>(Endpoints.meProgress, parse: (d) {
        raw = (d as List?) ?? const [];
        return raw.map((e) => ProgressItem.fromJson((e as Map).cast<String, dynamic>())).toList();
      });
      await _db.writeCache('progress', raw);
      return res.data;
    } on ApiException {
      final cached = await _db.readCache('progress');
      if (cached is List) {
        return cached.map((e) => ProgressItem.fromJson((e as Map).cast<String, dynamic>())).toList();
      }
      rethrow;
    }
  }

  Future<Preferences> getPreferences() async {
    final res = await _api.get(Endpoints.mePreferences,
        parse: (d) => Preferences.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Preferences> setPreferences(Preferences prefs) async {
    final res = await _api.put(Endpoints.mePreferences,
        body: prefs.toJson(), parse: (d) => Preferences.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<List<TestInfo>> tests() async {
    try {
      final res = await _api.get(Endpoints.tests,
          parse: (d) => (d as List).map((e) => TestInfo.fromJson((e as Map).cast<String, dynamic>())).toList());
      await _db.writeCache('tests', res.data.map((t) => t.toJson()).toList());
      return res.data;
    } on ApiException {
      final cached = await _db.readCache('tests');
      if (cached is List) {
        return cached.map((e) => TestInfo.fromJson((e as Map).cast<String, dynamic>())).toList();
      }
      rethrow;
    }
  }

  Map<String, dynamic> d2map(QuotaState q) =>
      {'used': q.used, 'max': q.max, 'base': q.base, 'unlimited': q.unlimited};
}
