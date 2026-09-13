import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Dispositivos push, bandeja de notificaciones y preferencias.
class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<String> registerDevice({required String platform, required String pushToken, String? deviceId}) async {
    final res = await _api.post(Endpoints.devices,
        body: {'platform': platform, 'pushToken': pushToken, if (deviceId != null) 'deviceId': deviceId},
        parse: (d) => (d as Map)['id']?.toString() ?? '');
    return res.data;
  }

  Future<void> unregisterDevice(String id) => _api.delete(Endpoints.device(id));

  Future<({List<NotificationItem> items, int unread})> list() async {
    int unread = 0;
    final res = await _api.get(Endpoints.meNotifications, parse: (d) {
      return (d as List).map((e) => NotificationItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    });
    unread = (res.meta?['unreadCount'] as num?)?.toInt() ?? 0;
    return (items: res.data, unread: unread);
  }

  Future<void> markRead(String id) => _api.patch(Endpoints.notificationRead(id));

  Future<void> setPreferences({required bool dailyReminder, String? reminderTime}) =>
      _api.put(Endpoints.notificationPreferences,
          body: {'dailyReminder': dailyReminder, if (reminderTime != null) 'reminderTime': reminderTime});
}
