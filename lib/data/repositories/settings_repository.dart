import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Ajustes de cuenta y exportación de datos.
class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<AppSettings> get() async {
    final res = await _api.get(Endpoints.meSettings,
        parse: (d) => AppSettings.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<AppSettings> patch({String? locale, String? theme, bool? dailyReminder}) async {
    final res = await _api.patch(Endpoints.meSettings,
        body: {
          if (locale != null) 'locale': locale,
          if (theme != null) 'theme': theme,
          if (dailyReminder != null) 'dailyReminder': dailyReminder,
        },
        parse: (d) => AppSettings.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<void> requestDataExport() => _api.get(Endpoints.meDataExport);
}
