import 'dart:convert';

import 'package:drift/drift.dart';

import 'connection/connection.dart';

part 'database.g.dart';

/// Preferencias locales clave/valor (tema, idioma, onboarding).
class AppPrefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  @override
  Set<Column> get primaryKey => {key};
}

/// Caché genérica de respuestas del API (listas y objetos) por clave.
class CacheEntries extends Table {
  TextColumn get cacheKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {cacheKey};
}

/// Caché de preguntas, para abrir/repasar sin conexión.
class CachedQuestions extends Table {
  TextColumn get id => text()();
  TextColumn get testId => text()();
  TextColumn get axis => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get statement => text()();
  TextColumn get optionsJson => text()();
  TextColumn get correctAnswer => text().nullable()();
  TextColumn get shortExplanation => text().nullable()();
  TextColumn get explanationJson => text().nullable()();
  TextColumn get skillJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Registro local de respuestas (auditoría/offline).
class AnswerLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get questionId => text()();
  TextColumn get selected => text()();
  BoolColumn get correct => boolean()();
  IntColumn get elapsedMs => integer()();
  DateTimeColumn get answeredAt => dateTime()();
}

@DriftDatabase(tables: [AppPrefs, CacheEntries, CachedQuestions, AnswerLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? openConnection());

  @override
  int get schemaVersion => 1;

  // ---- Preferencias ----
  Future<String?> getPref(String key) async {
    final row = await (select(appPrefs)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setPref(String key, String? value) {
    return into(appPrefs).insertOnConflictUpdate(
        AppPrefsCompanion.insert(key: key, value: Value(value)));
  }

  // ---- Caché genérica ----
  Future<dynamic> readCache(String key) async {
    final row = await (select(cacheEntries)..where((t) => t.cacheKey.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.payload);
  }

  Future<void> writeCache(String key, dynamic payload) {
    return into(cacheEntries).insertOnConflictUpdate(CacheEntriesCompanion.insert(
      cacheKey: key,
      payload: jsonEncode(payload),
      updatedAt: DateTime.now(),
    ));
  }

  // ---- Preguntas ----
  Future<void> upsertQuestion(CachedQuestionsCompanion q) =>
      into(cachedQuestions).insertOnConflictUpdate(q);

  Future<CachedQuestion?> question(String id) =>
      (select(cachedQuestions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Actualiza la respuesta correcta y explicación tras responder la pregunta en el servidor.
  Future<int> updateQuestionAnswer(String id, String correctAnswer, [String? shortExplanation]) =>
      (update(cachedQuestions)..where((t) => t.id.equals(id))).write(
        CachedQuestionsCompanion(
          correctAnswer: Value(correctAnswer),
          shortExplanation: Value(shortExplanation),
        ),
      );

  // ---- Respuestas ----
  Future<void> logAnswer(AnswerLogsCompanion log) => into(answerLogs).insert(log);

  Future<void> wipe() async {
    await delete(cacheEntries).go();
    await delete(cachedQuestions).go();
    await delete(answerLogs).go();
    await delete(appPrefs).go();
  }
}

