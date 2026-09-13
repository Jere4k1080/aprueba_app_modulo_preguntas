import 'dart:convert';

import 'package:aprueba_app/core/network/api_client.dart';
import 'package:aprueba_app/core/network/endpoints.dart';
import 'package:aprueba_app/core/storage/secure_storage.dart';
import 'package:aprueba_app/data/local/database.dart';
import 'package:aprueba_app/data/repositories/practice_repository.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends SecureStorage {
  @override
  Future<String?> get accessToken => Future.value('test_jwt_token');
  @override
  Future<String?> get refreshToken => Future.value('test_refresh_token');
}

void main() {
  late AppDatabase db;
  late PracticeRepository repository;

  setUp(() {
    // Base de datos Drift en memoria para aislar cada prueba.
    db = AppDatabase(NativeDatabase.memory());

    // Dio simulado con interceptor que devuelve payloads canónicos del contrato.
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == Endpoints.practiceNext) {
          // Payload canónico de GET /practice/next: NUNCA incluye correctAnswer
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'id': 'q_drift_test_01',
                'testId': 'm1',
                'axis': 'Álgebra y Funciones',
                'difficulty': 'd2',
                'statement': '¿Cuál es el valor de x si 3x - 9 = 0?',
                'options': ['1', '2', '3', '4'],
                'progress': {'current': 1, 'total': 10},
              },
              'error': null,
              'meta': {
                'quota': {'used': 2, 'max': 10},
              },
            },
          ));
        }

        if (options.path == Endpoints.answer('q_drift_test_01')) {
          // Payload canónico de POST /questions/:id/answer: SÍ entrega la respuesta y explicación
          return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'correct': true,
                'correctAnswer': 'C',
                'shortExplanation': 'Despejando: 3x = 9 => x = 3.',
                'cohortPercentile': 85,
                'medalAwarded': {'tier': 'bronze', 'amount': 1},
                'quota': {'used': 3, 'max': 10},
              },
              'error': null,
              'meta': {
                'requestId': 'req_test_123',
                'timestamp': '2026-09-15T10:00:00.000Z',
              },
            },
          ));
        }

        handler.next(options);
      },
    ));

    final api = ApiClient(_FakeSecureStorage(), dio: dio);
    repository = PracticeRepository(api, db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Regla de integridad de caché local (Drift)', () {
    test('Prueba A: next() cachea la pregunta pero correctAnswer permanece estrictamente NULO', () async {
      // 1. El estudiante pide la siguiente pregunta para resolver
      final nextResult = await repository.next();
      expect(nextResult.question.id, 'q_drift_test_01');

      // 2. Leemos la fila persistida en Drift
      final cached = await db.question('q_drift_test_01');
      expect(cached, isNotNull, reason: 'La pregunta debe haberse guardado en caché local para soporte offline');
      expect(cached!.id, 'q_drift_test_01');
      expect(cached.statement, contains('3x - 9 = 0'));

      // 3. Regla de integridad fundamental: la respuesta correcta NUNCA debe estar en el dispositivo antes de responder
      expect(cached.correctAnswer, isNull,
          reason: 'Vulnerabilidad de integridad evitada: correctAnswer debe ser NULL antes de responder');
      expect(cached.shortExplanation, isNull,
          reason: 'shortExplanation también debe ser NULL antes de responder');
    });

    test('Prueba B: tras responder, updateQuestionAnswer puebla correctAnswer y shortExplanation para repaso offline', () async {
      // 1. Descargamos y cacheamos la pregunta inicial
      await repository.next();

      final beforeAnswer = await db.question('q_drift_test_01');
      expect(beforeAnswer!.correctAnswer, isNull);

      // 2. El estudiante responde la pregunta en el servidor
      final answerResult = await repository.answer(
        questionId: 'q_drift_test_01',
        selected: 'C',
        elapsedMs: 18500,
      );

      expect(answerResult.correct, isTrue);
      expect(answerResult.correctAnswer, 'C');

      // 3. Leemos la fila en Drift: ahora SÍ debe estar poblada para el repaso sin conexión
      final afterAnswer = await db.question('q_drift_test_01');
      expect(afterAnswer, isNotNull);
      expect(afterAnswer!.correctAnswer, 'C',
          reason: 'Tras responder, la caché debe guardar la clave correcta para que el estudiante pueda repasar offline');
      expect(afterAnswer.shortExplanation, 'Despejando: 3x = 9 => x = 3.',
          reason: 'La explicación breve debe estar disponible offline tras la resolución');

      // 4. Se verifica que además se registre el log en AnswerLogs
      final logs = await db.select(db.answerLogs).get();
      expect(logs.length, 1);
      expect(logs.first.questionId, 'q_drift_test_01');
      expect(logs.first.selected, 'C');
      expect(logs.first.correct, isTrue);
      expect(logs.first.elapsedMs, 18500);
    });

    test('Prueba C: updateQuestionAnswer actualiza registros existentes de forma idempotente', () async {
      // Inserción directa de pregunta sin respuesta
      await db.upsertQuestion(CachedQuestionsCompanion.insert(
        id: 'q_direct_01',
        testId: 'cien',
        statement: 'Pregunta directa',
        optionsJson: jsonEncode(['A', 'B']),
      ));

      final q0 = await db.question('q_direct_01');
      expect(q0!.correctAnswer, isNull);

      // Actualización directa usando la nueva función de Drift
      final rowsUpdated = await db.updateQuestionAnswer('q_direct_01', 'A', 'Explicación directa');
      expect(rowsUpdated, 1);

      final q1 = await db.question('q_direct_01');
      expect(q1!.correctAnswer, 'A');
      expect(q1.shortExplanation, 'Explicación directa');
    });
  });
}
