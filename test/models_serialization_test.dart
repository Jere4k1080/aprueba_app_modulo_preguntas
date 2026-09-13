import 'package:aprueba_app/data/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Question (Banco de preguntas)', () {
    test('Question.fromJson parsea documento completo de Firestore', () {
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

    test('Question.toJson serializa fielmente para Firestore (roundtrip)', () {
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

    test('Question asigna status active por defecto si se omite', () {
      final q = Question.fromJson({
        'id': 'q_min_001',
        'testId': 'm2',
        'statement': 'Pregunta mínima',
        'options': ['A', 'B'],
      });

      expect(q.status, 'active');
      expect(q.skillId, isNull);
      expect(q.correctAnswer, isNull);
      expect(q.explanation, isNull);
      expect(q.progressCurrent, isNull);
    });
  });

  group('FirestoreTest (Pruebas PAES)', () {
    test('FirestoreTest parsea y serializa los cinco tests oficiales', () {
      final testsData = [
        {'id': 'lectora', 'label': 'Comp. Lectora', 'color': '#1A365D', 'hasQuestions': true},
        {'id': 'm1', 'label': 'Matemática M1', 'color': '#10B981', 'hasQuestions': true},
        {'id': 'm2', 'label': 'Matemática M2', 'color': '#6366F1', 'hasQuestions': true},
        {'id': 'cien', 'label': 'Ciencias', 'color': '#F5B041', 'hasQuestions': true},
        {'id': 'hist', 'label': 'Historia y C. Soc.', 'color': '#EF4444', 'hasQuestions': true},
      ];

      for (final data in testsData) {
        final t = FirestoreTest.fromJson(data);
        expect(t.id, data['id']);
        expect(t.label, data['label']);
        expect(t.color, data['color']);
        expect(t.hasQuestions, isTrue);

        final json = t.toJson();
        expect(json['id'], data['id']);
        expect(json['label'], data['label']);
        expect(json['color'], data['color']);
        expect(json['hasQuestions'], true);
      }
    });
  });

  group('FirestoreSkill y SkillResource (Habilidades y prerrequisitos)', () {
    test('FirestoreSkill parsea árbol de prerrequisitos y recursos', () {
      final json = {
        'id': 'sk_cien_fis_01',
        'name': 'Cinemática y Dinámica',
        'testId': 'cien',
        'domain': 'Física Mecánica',
        'level': 2,
        'maxLevel': 4,
        'prerequisiteIds': ['sk_cien_mat_basica', 'sk_cien_vectores'],
        'status': 'active',
        'resources': [
          {
            'type': 'video',
            'title': 'Leyes de Newton en 10 minutos',
            'url': 'https://youtube.com/watch?v=example1',
            'duration': '10 min',
            'source': 'YouTube',
          },
          {
            'type': 'pdf',
            'title': 'Guía resumen de cinemática',
            'url': 'https://cdn.aprueba.cl/guias/cinematica.pdf',
            'source': 'Aprueba',
          },
        ],
      };

      final skill = FirestoreSkill.fromJson(json);

      expect(skill.id, 'sk_cien_fis_01');
      expect(skill.name, 'Cinemática y Dinámica');
      expect(skill.testId, 'cien');
      expect(skill.domain, 'Física Mecánica');
      expect(skill.level, 2);
      expect(skill.maxLevel, 4);
      expect(skill.prerequisiteIds, containsAll(['sk_cien_mat_basica', 'sk_cien_vectores']));
      expect(skill.status, 'active');
      expect(skill.resources.length, 2);

      final r1 = skill.resources[0];
      expect(r1.type, 'video');
      expect(r1.title, 'Leyes de Newton en 10 minutos');
      expect(r1.duration, '10 min');
      expect(r1.source, 'YouTube');

      final r2 = skill.resources[1];
      expect(r2.type, 'pdf');
      expect(r2.duration, isNull);
    });

    test('FirestoreSkill serializa y recupera via roundtrip', () {
      const original = FirestoreSkill(
        id: 'sk_hist_01',
        name: 'Construcción del Estado-Nación',
        testId: 'hist',
        domain: 'Historia de Chile',
        level: 1,
        maxLevel: 4,
        prerequisiteIds: ['sk_hist_independencia'],
        status: 'done',
        resources: [
          SkillResource(type: 'exercise', title: 'Mini facsímil 5 preguntas'),
        ],
      );

      final json = original.toJson();
      final roundtrip = FirestoreSkill.fromJson(json);

      expect(roundtrip.id, original.id);
      expect(roundtrip.name, original.name);
      expect(roundtrip.testId, original.testId);
      expect(roundtrip.domain, original.domain);
      expect(roundtrip.level, 1);
      expect(roundtrip.status, 'done');
      expect(roundtrip.prerequisiteIds, ['sk_hist_independencia']);
      expect(roundtrip.resources.single.type, 'exercise');
    });
  });

  group('FirestoreAnswer (Respuestas de alumnos)', () {
    test('FirestoreAnswer parsea respuesta con percentil de cohorte', () {
      final json = {
        'id': 'ans_101',
        'userId': 'usr_jeremias',
        'questionId': 'q_lectora_001',
        'selected': 'B',
        'correct': true,
        'elapsedMs': 28500,
        'cohortPercentile': 85,
        'answeredAt': '2026-09-15T10:30:00.000Z',
      };

      final ans = FirestoreAnswer.fromJson(json);

      expect(ans.id, 'ans_101');
      expect(ans.userId, 'usr_jeremias');
      expect(ans.questionId, 'q_lectora_001');
      expect(ans.selected, 'B');
      expect(ans.correct, isTrue);
      expect(ans.elapsedMs, 28500);
      expect(ans.cohortPercentile, 85);
      expect(ans.answeredAt, DateTime.parse('2026-09-15T10:30:00.000Z'));
    });

    test('FirestoreAnswer roundtrip serializa campos requeridos y opcionales', () {
      final original = FirestoreAnswer(
        id: 'ans_102',
        userId: 'usr_seba',
        questionId: 'q_m1_042',
        selected: 'A',
        correct: false,
        elapsedMs: 65000,
        answeredAt: DateTime.parse('2026-09-15T11:00:00.000Z'),
      );

      final json = original.toJson();
      expect(json.containsKey('cohortPercentile'), isFalse);
      expect(json['userId'], 'usr_seba');

      final roundtrip = FirestoreAnswer.fromJson(json);
      expect(roundtrip.id, original.id);
      expect(roundtrip.correct, isFalse);
      expect(roundtrip.cohortPercentile, isNull);
    });
  });

  group('Correction (Recorrecciones y tipificación de causas)', () {
    test('Correction parsea reporte pendiente con potentialReward', () {
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
      expect(c.rewardAmount, 250);
      expect(c.reviewedAt, isNull);
      expect(c.reviewedBy, isNull);
    });

    test('Correction parsea reporte confirmado con rewardGranted y revisor', () {
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
      expect(c.reviewedBy, 'admin_karina');
      expect(c.reviewedAt, isNotNull);
    });

    test('Correction valida las cinco razones tipificadas del contrato', () {
      for (final reason in Correction.reasons) {
        final c = Correction.fromJson({
          'id': 'cor_test',
          'questionId': 'q_001',
          'reason': reason,
          'status': 'pending',
        });
        expect(c.reason, reason);
      }
      expect(Correction.reasons, [
        'wrong_answer',
        'ambiguous',
        'typo',
        'bad_explanation',
        'other',
      ]);
    });

    test('Correction roundtrip conserva todos los campos', () {
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

  group('MedalLedgerEntry (Movimientos de medallas)', () {
    test('MedalLedgerEntry parsea movimiento positivo (premio por respuesta)', () {
      final json = {
        'id': 'ml_001',
        'type': 'answer_correct',
        'tier': 'bronze',
        'amount': 1,
        'referenceId': 'q_lectora_001',
        'createdAt': '2026-09-15T10:30:01.000Z',
      };

      final entry = MedalLedgerEntry.fromJson(json);

      expect(entry.id, 'ml_001');
      expect(entry.type, 'answer_correct');
      expect(entry.tier, 'bronze');
      expect(entry.amount, 1);
      expect(entry.referenceId, 'q_lectora_001');
      expect(entry.createdAt, DateTime.parse('2026-09-15T10:30:01.000Z'));
    });

    test('MedalLedgerEntry parsea gasto negativo (intercambio de medallas)', () {
      final json = {
        'id': 'ml_002',
        'type': 'exchange',
        'tier': 'bronze',
        'amount': -5,
        'referenceId': 'exchange_to_silver',
        'createdAt': '2026-09-15T11:00:00.000Z',
      };

      final entry = MedalLedgerEntry.fromJson(json);

      expect(entry.amount, -5);
      expect(entry.type, 'exchange');

      final roundtrip = MedalLedgerEntry.fromJson(entry.toJson());
      expect(roundtrip.amount, -5);
      expect(roundtrip.tier, 'bronze');
    });
  });

  group('UserQuotaState y QuotaState (Cuotas y bonificaciones)', () {
    test('UserQuotaState parsea mapa de bonificaciones extensible', () {
      final json = {
        'used': 8,
        'max': 20,
        'base': 10,
        'bonuses': {'school': true, 'address': true, 'early_bird': false},
        'unlimited': false,
        'resetsAt': '2026-09-16T00:00:00.000Z',
      };

      final q = UserQuotaState.fromJson(json);

      expect(q.used, 8);
      expect(q.max, 20);
      expect(q.base, 10);
      expect(q.bonuses['school'], isTrue);
      expect(q.bonuses['address'], isTrue);
      expect(q.bonuses['early_bird'], isFalse);
      expect(q.unlimited, isFalse);
      expect(q.resetsAt, isNotNull);

      final out = q.toJson();
      expect(out['bonuses']['school'], true);
      expect(out['resetsAt'], '2026-09-16T00:00:00.000Z');
    });

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
    });
  });
}
