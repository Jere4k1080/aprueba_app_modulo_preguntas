import 'package:aprueba_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Question (Modelo de dominio del cliente)', () {
    test('Question.fromJson parsea payload de práctica', () {
      final json = {
        'id': 'q_lectora_001',
        'testId': 'lectora',
        'axis': 'Comprensión lectora',
        'skillId': 'sk_lectora_comp_lit',
        'difficulty': 'd2',
        'statement': '¿Cuál es la idea principal del texto presentado?',
        'options': [
          'La evolución del lenguaje en los medios',
          'El impacto ambiental del desarrollo urbano',
          'La preservación de las tradiciones orales',
          'El conflicto generacional en el siglo XXI',
        ],
        'correctAnswer': 'B',
        'explanation': 'El segundo párrafo destaca explícitamente el impacto ambiental.',
        'status': 'active',
        'progress': {'current': 3, 'total': 10},
      };

      final q = Question.fromJson(json);

      expect(q.id, 'q_lectora_001');
      expect(q.testId, 'lectora');
      expect(q.axis, 'Comprensión lectora');
      expect(q.skillId, 'sk_lectora_comp_lit');
      expect(q.difficulty, 'd2');
      expect(q.statement, contains('idea principal'));
      expect(q.options.length, 4);
      expect(q.correctAnswer, 'B');
      expect(q.explanation, contains('impacto ambiental'));
      expect(q.status, 'active');
      expect(q.progressCurrent, 3);
      expect(q.progressTotal, 10);
    });

    test('Question.toJson serializa fielmente (roundtrip)', () {
      final original = Question(
        id: 'q_m1_042',
        testId: 'm1',
        axis: 'Números y Álgebra',
        skillId: 'sk_m1_ecuaciones',
        difficulty: 'd3',
        statement: 'Si 2x + 5 = 15, ¿cuál es el valor de x?',
        options: ['3', '5', '7', '10'],
        correctAnswer: 'B',
        explanation: '2x = 10, por ende x = 5.',
        status: 'active',
      );

      final json = original.toJson();
      final roundtrip = Question.fromJson(json);

      expect(roundtrip.id, original.id);
      expect(roundtrip.testId, original.testId);
      expect(roundtrip.axis, original.axis);
      expect(roundtrip.skillId, original.skillId);
      expect(roundtrip.difficulty, original.difficulty);
      expect(roundtrip.statement, original.statement);
      expect(roundtrip.options, original.options);
      expect(roundtrip.correctAnswer, original.correctAnswer);
      expect(roundtrip.explanation, original.explanation);
      expect(roundtrip.status, 'active');
    });

    test('Question maneja correctAnswer nulo cuando el backend lo omite por seguridad', () {
      // En GET /practice/next el backend NUNCA debe enviar correctAnswer
      final q = Question.fromJson({
        'id': 'q_secure_001',
        'testId': 'm1',
        'statement': 'Pregunta en curso',
        'options': ['A', 'B', 'C', 'D'],
        'difficulty': 'd1',
      });

      expect(q.correctAnswer, isNull);
      expect(q.status, 'active');
      expect(q.skillId, isNull);
      expect(q.progressCurrent, isNull);
    });
  });

  group('Correction (Modelo de recorrección del cliente)', () {
    test('Correction parsea reporte pendiente con potentialReward {amount}', () {
      final json = {
        'id': 'cor_501',
        'userId': 'usr_jeremias',
        'questionId': 'q_lectora_001',
        'reason': 'wrong_answer',
        'comment': 'La opción C también describe la idea del texto',
        'status': 'pending',
        'potentialReward': {'amount': 250},
        'createdAt': '2026-09-15T12:00:00.000Z',
      };

      final c = Correction.fromJson(json);

      expect(c.id, 'cor_501');
      expect(c.userId, 'usr_jeremias');
      expect(c.questionId, 'q_lectora_001');
      expect(c.reason, 'wrong_answer');
      expect(c.comment, contains('opción C'));
      expect(c.status, 'pending');
      expect(c.potentialReward, 250);
      expect(c.rewardAmount, isNull);
      expect(c.reviewedAt, isNull);
      expect(c.reviewedBy, isNull);
    });

    test('Correction parsea reporte confirmado con rewardGranted {amount}', () {
      final json = {
        'id': 'cor_502',
        'userId': 'usr_seba',
        'questionId': 'q_m1_042',
        'reason': 'typo',
        'comment': 'Hay un error tipográfico en la alternativa D',
        'status': 'confirmed',
        'rewardGranted': {'amount': 250},
        'createdAt': '2026-09-14T08:00:00.000Z',
        'reviewedAt': '2026-09-14T14:30:00.000Z',
        'reviewedBy': 'admin_karina',
      };

      final c = Correction.fromJson(json);

      expect(c.status, 'confirmed');
      expect(c.rewardAmount, 250);
      expect(c.potentialReward, isNull);
      expect(c.reviewedBy, 'admin_karina');
      expect(c.reviewedAt, isNotNull);
    });

    test('Correction valida las cinco razones canónicas y tres estados del contrato', () {
      expect(Correction.reasons, [
        'wrong_answer',
        'ambiguous',
        'typo',
        'bad_explanation',
        'other',
      ]);
      expect(Correction.statuses, ['pending', 'confirmed', 'rejected']);

      for (final reason in Correction.reasons) {
        final c = Correction.fromJson({
          'id': 'cor_test',
          'questionId': 'q_001',
          'reason': reason,
          'status': 'pending',
        });
        expect(c.reason, reason);
      }
    });

    test('Correction roundtrip conserva todos los campos del contrato', () {
      final original = Correction(
        id: 'cor_503',
        userId: 'usr_martin',
        questionId: 'q_hist_010',
        reason: 'bad_explanation',
        comment: 'La explicación no cita la fuente.',
        status: 'pending',
        potentialReward: 250,
        createdAt: DateTime.parse('2026-09-15T16:00:00.000Z'),
      );

      final json = original.toJson();
      final roundtrip = Correction.fromJson(json);

      expect(roundtrip.id, original.id);
      expect(roundtrip.userId, original.userId);
      expect(roundtrip.potentialReward, 250);
      expect(roundtrip.status, 'pending');
      expect(roundtrip.createdAt, original.createdAt);
    });
  });

  group('QuotaState (Modelo de cuota del cliente)', () {
    test('QuotaState serializa a JSON correctamente (roundtrip)', () {
      final q = QuotaState(
        used: 5,
        max: 15,
        base: 10,
        schoolBonus: true,
        addressBonus: false,
        unlimited: false,
        resetsAt: DateTime.parse('2026-09-16T04:00:00.000Z'),
      );

      final json = q.toJson();
      final roundtrip = QuotaState.fromJson(json);

      expect(roundtrip.used, 5);
      expect(roundtrip.max, 15);
      expect(roundtrip.schoolBonus, isTrue);
      expect(roundtrip.addressBonus, isFalse);
      expect(roundtrip.unlimited, isFalse);
      expect(roundtrip.resetsAt, q.resetsAt);
    });
  });
}
