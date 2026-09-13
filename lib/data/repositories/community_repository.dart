import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Muro de la comunidad: feed, publicaciones, likes y comentarios.
class CommunityRepository {
  CommunityRepository(this._api);
  final ApiClient _api;

  Future<({List<Post> posts, String? nextCursor})> feed({String? cursor, int limit = 20}) async {
    final res = await _api.get(Endpoints.feed,
        query: {if (cursor != null) 'cursor': cursor, 'limit': limit},
        parse: (d) => (d as List).map((e) => Post.fromJson((e as Map).cast<String, dynamic>())).toList());
    return (posts: res.data, nextCursor: res.nextCursor);
  }

  Future<Post> createPost({required String text, String? questionId}) async {
    final res = await _api.post(Endpoints.posts,
        body: {'text': text, if (questionId != null) 'questionId': questionId},
        parse: (d) => Post.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<({bool liked, int likes})> toggleLike(String postId) async {
    final res = await _api.post(Endpoints.postLike(postId), parse: (d) => d);
    final m = (res.data as Map).cast<String, dynamic>();
    return (liked: (m['liked'] ?? false) as bool, likes: (m['likes'] as num?)?.toInt() ?? 0);
  }

  Future<void> comment(String postId, String text) =>
      _api.post(Endpoints.postComments(postId), body: {'text': text});
}
