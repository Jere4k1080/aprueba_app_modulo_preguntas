import 'package:flutter_test/flutter_test.dart';

import 'package:aprueba_app/data/models/models.dart';

void main() {
  test('User.fromJson parsea perfil con cuota y medallas', () {
    final u = User.fromJson({
      'id': 'usr_1',
      'name': 'Camila',
      'plan': 'all',
      'streak': 4,
      'quota': {'used': 5, 'max': 10},
      'medals': {'bronze': 14, 'silver': 3, 'gold': 1},
    });
    expect(u.isPaid, true);
    expect(u.quotaUsed, 5);
    expect(u.medals.bronze, 14);
  });

  test('Medals.nextTier sigue la ruta de canje', () {
    expect(Medals.nextTier('bronze'), 'silver');
    expect(Medals.nextTier('platinum'), null);
  });

  test('AnswerResult mapea medalla y percentil', () {
    final r = AnswerResult.fromJson({
      'correct': true,
      'correctAnswer': 'B',
      'shortExplanation': 'x = 5',
      'cohortPercentile': 72,
      'medalAwarded': {'tier': 'bronze', 'amount': 1},
      'quota': {'used': 6, 'max': 10},
    });
    expect(r.correct, true);
    expect(r.medalTier, 'bronze');
    expect(r.cohortPercentile, 72);
  });
}
