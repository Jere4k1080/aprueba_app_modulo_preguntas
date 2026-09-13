import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Chat con tutores. El transporte es REST + polling: la UI vuelve a pedir los
/// mensajes cada AppConfig.chatPollInterval y usa `unreadCount` para el badge.
class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Conversation>> conversations() async {
    final res = await _api.get<List<Conversation>>(
      Endpoints.meConversations,
      parse: (d) => (d as List)
          .map((e) => Conversation.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data;
  }

  Future<ConversationDetail> detail(String id) async {
    final res = await _api.get(
      Endpoints.conversation(id),
      parse: (d) => ConversationDetail.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  /// Los mensajes llegan del más reciente al más antiguo. `markRead: false`
  /// permite refrescar sin consumir el badge.
  Future<List<ChatMessage>> messages(String id, {String? cursor, bool markRead = true}) async {
    final res = await _api.get<List<ChatMessage>>(
      Endpoints.conversationMessages(id),
      query: {
        if (cursor != null) 'cursor': cursor,
        if (!markRead) 'markRead': 'false',
      },
      parse: (d) => (d as List)
          .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
    return res.data;
  }

  Future<ChatMessage> send(String id, String text) async {
    final res = await _api.post(
      Endpoints.conversationMessages(id),
      body: {'text': text},
      parse: (d) => ChatMessage.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  Future<void> markRead(String id) => _api.post(Endpoints.conversationRead(id));

  /// El teléfono se revela solo si el tutor también aceptó compartirlo.
  Future<ContactSharing> setContactSharing(String id, bool share) async {
    final res = await _api.patch(
      Endpoints.conversationContactSharing(id),
      body: {'shareWhatsapp': share},
      parse: (d) => ContactSharing.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }
}
