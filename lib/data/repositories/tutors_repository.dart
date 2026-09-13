import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Filtros del marketplace (pantalla `tutors` del wireframe).
class TutorFilters {
  const TutorFilters({this.query, this.subject, this.mode, this.verifiedOnly = false, this.sort = 'rating'});
  final String? query;
  final String? subject;
  final String? mode; // online | in_person
  final bool verifiedOnly;
  final String sort; // rating | price_asc | price_desc | experience

  TutorFilters copyWith({
    String? query,
    String? subject,
    String? mode,
    bool? verifiedOnly,
    String? sort,
    bool clearSubject = false,
    bool clearMode = false,
  }) =>
      TutorFilters(
        query: query ?? this.query,
        subject: clearSubject ? null : subject ?? this.subject,
        mode: clearMode ? null : mode ?? this.mode,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        sort: sort ?? this.sort,
      );

  Map<String, dynamic> toQuery() => {
        if (query != null && query!.trim().isNotEmpty) 'q': query!.trim(),
        if (subject != null) 'subject': subject,
        if (mode != null) 'mode': mode,
        if (verifiedOnly) 'verified': 'true',
        'sort': sort,
      };

  @override
  bool operator ==(Object other) =>
      other is TutorFilters &&
      other.query == query &&
      other.subject == subject &&
      other.mode == mode &&
      other.verifiedOnly == verifiedOnly &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(query, subject, mode, verifiedOnly, sort);
}

/// Tutores: listado, perfil, reseñas, solicitud de contacto y análisis de
/// falencias. Contacto y análisis exigen plan de pago (403 PLAN_REQUIRED).
class TutorsRepository {
  TutorsRepository(this._api);
  final ApiClient _api;

  Future<List<Tutor>> list([TutorFilters filters = const TutorFilters()]) async {
    final res = await _api.get<List<Tutor>>(
      Endpoints.tutors,
      query: filters.toQuery(),
      parse: (d) => (d as List).map((e) => Tutor.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
    return res.data;
  }

  Future<List<Tutor>> featured() async {
    final res = await _api.get<List<Tutor>>(
      Endpoints.tutorsFeatured,
      parse: (d) => (d as List).map((e) => Tutor.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
    return res.data;
  }

  Future<Tutor> detail(String id) async {
    final res = await _api.get(
      Endpoints.tutor(id),
      parse: (d) => Tutor.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  Future<TutorReviewPage> reviews(String id, {String? cursor}) async {
    final res = await _api.get<List<TutorReview>>(
      Endpoints.tutorReviews(id),
      query: {if (cursor != null) 'cursor': cursor},
      parse: (d) => (d as List).map((e) => TutorReview.fromJson((e as Map).cast<String, dynamic>())).toList(),
    );
    final summary = (res.meta?['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pagination = (res.meta?['pagination'] as Map?)?.cast<String, dynamic>();
    return TutorReviewPage(
      reviews: res.data,
      overall: (summary['overall'] as num?)?.toDouble() ?? 0,
      reviewCount: (summary['reviewCount'] as num?)?.toInt() ?? res.data.length,
      byCriterion: ((summary['byCriterion'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CriterionValue.fromJson(e.cast<String, dynamic>()))
          .toList(),
      nextCursor: pagination?['nextCursor'] as String?,
    );
  }

  /// Publica la reseña de 3 criterios (1..5) del wireframe.
  Future<TutorReview> publishReview({
    required String tutorId,
    required int teaching,
    required int punctuality,
    required int mastery,
    String comment = '',
  }) async {
    final res = await _api.post(
      Endpoints.tutorReviews(tutorId),
      body: {
        'ratings': {'teaching': teaching, 'punctuality': punctuality, 'mastery': mastery},
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
      parse: (d) {
        final map = (d as Map).cast<String, dynamic>();
        final review = map['review'];
        return TutorReview.fromJson(
            review is Map ? review.cast<String, dynamic>() : map);
      },
    );
    return res.data;
  }

  /// Premium. Devuelve la conversación creada (o la existente).
  Future<ContactRequestResult> contact({
    required String tutorId,
    required String message,
    bool shareProfile = true,
  }) async {
    final res = await _api.post(
      Endpoints.tutorContactRequests(tutorId),
      body: {'message': message, 'shareProfile': shareProfile},
      parse: (d) => ContactRequestResult.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }

  /// Premium.
  Future<GapAnalysis> gapAnalysis() async {
    final res = await _api.get(
      Endpoints.meGapAnalysis,
      parse: (d) => GapAnalysis.fromJson((d as Map).cast<String, dynamic>()),
    );
    return res.data;
  }
}
