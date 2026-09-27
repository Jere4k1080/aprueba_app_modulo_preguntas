import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../local/database.dart';
import '../models/models.dart';

/// Núcleo de práctica: siguiente pregunta, corrección, explicación,
/// habilidad y recorrecciones. Cachea preguntas para repaso offline.
class PracticeRepository {
  PracticeRepository(this._api, this._db);
  final ApiClient _api;
  final AppDatabase _db;

  /// Siguiente pregunta, sin la respuesta correcta, con la cuota del día que
  /// llega en meta.quota.
  Future<({Question question, QuotaState? quota})> next() async {
    final res = await _api.get<Question>(Endpoints.practiceNext, parse: (d) {
      return Question.fromJson((d as Map).cast<String, dynamic>());
    });
    final quota = (res.meta?['quota'] as Map?)?.cast<String, dynamic>();
    await _cacheQuestion(res.data);
    return (question: res.data, quota: quota == null ? null : QuotaState.fromJson(quota));
  }

  Future<Question> question(String id) async {
    final res = await _api.get(Endpoints.question(id),
        parse: (d) => Question.fromJson((d as Map).cast<String, dynamic>()));
    await _cacheQuestion(res.data);
    return res.data;
  }

  Future<AnswerResult> answer({
    required String questionId,
    required String selected,
    required int elapsedMs,
    String? sessionId,
  }) async {
    final res = await _api.post(
      Endpoints.answer(questionId),
      body: {'selected': selected, 'elapsedMs': elapsedMs, if (sessionId != null) 'sessionId': sessionId},
      parse: (d) => AnswerResult.fromJson((d as Map).cast<String, dynamic>()),
    );
    final r = res.data;
    await _db.logAnswer(AnswerLogsCompanion.insert(
      questionId: questionId,
      selected: selected,
      correct: r.correct,
      elapsedMs: elapsedMs,
      answeredAt: DateTime.now(),
    ));
    if (r.correctAnswer.isNotEmpty) {
      await _db.updateQuestionAnswer(questionId, r.correctAnswer, r.shortExplanation);
    }
    return r;
  }

  Future<Explanation> explanation(String questionId) async {
    final res = await _api.get(Endpoints.explanation(questionId),
        parse: (d) => Explanation.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<SkillInfo> skill(String questionId) async {
    final res = await _api.get(Endpoints.skill(questionId),
        parse: (d) => SkillInfo.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Correction> createCorrection({required String questionId, required String reason, String? comment}) async {
    final res = await _api.post(Endpoints.corrections,
        body: {'questionId': questionId, 'reason': reason, if (comment != null) 'comment': comment},
        parse: (d) => Correction.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<List<Correction>> corrections() async {
    final res = await _api.get(Endpoints.corrections,
        parse: (d) => (d as List).map((e) => Correction.fromJson((e as Map).cast<String, dynamic>())).toList());
    return res.data;
  }

  Future<void> _cacheQuestion(Question q) => _db.upsertQuestion(CachedQuestionsCompanion.insert(
        id: q.id,
        testId: q.testId,
        axis: Value(q.axis),
        difficulty: Value(q.difficulty),
        statement: q.statement,
        optionsJson: jsonEncode(q.options),
      ));
}
