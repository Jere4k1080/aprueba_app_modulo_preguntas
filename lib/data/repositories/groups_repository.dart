import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Grupos de estudio, invitaciones, estadísticas y preguntas compartidas.
class GroupsRepository {
  GroupsRepository(this._api);
  final ApiClient _api;

  Future<List<Group>> list() async {
    final res = await _api.get(Endpoints.groups,
        parse: (d) => (d as List).map((e) => Group.fromJson((e as Map).cast<String, dynamic>())).toList());
    return res.data;
  }

  Future<Group> create({required String name, required String subjectTestId}) async {
    final res = await _api.post(Endpoints.groups,
        body: {'name': name, 'subjectTestId': subjectTestId},
        parse: (d) => Group.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Group> detail(String id) async {
    final res = await _api.get(Endpoints.group(id),
        parse: (d) => Group.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<void> update(String id, {String? name, String? subjectTestId}) =>
      _api.patch(Endpoints.group(id), body: {if (name != null) 'name': name, if (subjectTestId != null) 'subjectTestId': subjectTestId});

  Future<void> remove(String id) => _api.delete(Endpoints.group(id));

  Future<void> invite(String groupId, String email) =>
      _api.post(Endpoints.groupInvitations(groupId), body: {'email': email});

  Future<void> acceptInvitation(String token) => _api.post(Endpoints.invitationAccept(token));

  Future<void> leave(String groupId, String userId) =>
      _api.delete(Endpoints.groupMember(groupId, userId));

  Future<GroupStats> stats(String id) async {
    final res = await _api.get(Endpoints.groupStats(id),
        parse: (d) => GroupStats.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<void> share(String groupId, {required String questionId, String? answerId, String? comment}) =>
      _api.post(Endpoints.groupShared(groupId), body: {
        'questionId': questionId,
        if (answerId != null) 'answerId': answerId,
        if (comment != null) 'comment': comment,
      });
}
