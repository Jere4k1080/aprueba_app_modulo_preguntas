import 'package:aprueba_app/features/onboarding/education_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// El catálogo local es solo el respaldo de /countries/:code/grades y
/// /tests?gradeId=. Los ids deben coincidir con los del backend
/// (aprueba_student_web/backend/src/data/catalog.js).
void main() {
  test('normaliza GB al codigo UK que usa el backend', () {
    expect(EducationCatalog.normalizeCountry('GB'), 'UK');
    expect(EducationCatalog.normalizeCountry('uk'), 'UK');
    expect(EducationCatalog.normalizeCountry(null), 'CL');
    expect(EducationCatalog.normalizeCountry('XX'), 'CL');
  });

  test('Chile incluye basica, media y PAES', () {
    final ids = EducationCatalog.gradeGroupsFor('CL', 'es')
        .expand((group) => group.items)
        .map((item) => item.id);

    expect(ids, containsAll(['cl-basic-1', 'cl-media-4', 'cl-paes']));
  });

  test('Reino Unido incluye Years, GCSE y A levels', () {
    final items = EducationCatalog.gradeGroupsFor('UK', 'en')
        .expand((group) => group.items)
        .toList();

    expect(items.map((i) => i.id),
        containsAll(['uk-year-1', 'uk-year-13', 'uk-gcse', 'uk-a-levels']));
    expect(items.firstWhere((i) => i.id == 'uk-a-levels').kind, 'exam');
  });

  test('las asignaturas dependen del grado y del pais', () {
    final paes = EducationCatalog.subjectsFallback(gradeId: 'cl-paes', lang: 'es');
    final aLevels = EducationCatalog.subjectsFallback(gradeId: 'uk-a-levels', lang: 'en');
    final school = EducationCatalog.subjectsFallback(gradeId: 'cl-media-2', lang: 'es');

    expect(paes.map((s) => s.id), contains('m1'));
    expect(paes.every((s) => s.hasQuestions), isTrue);
    expect(aLevels.map((s) => s.id), contains('eng-lit'));
    expect(school.map((s) => s.id), contains('language'));
    // Las asignaturas escolares todavia no tienen banco de preguntas.
    expect(school.every((s) => s.hasQuestions), isFalse);
  });

  test('sin grado cae en el catalogo PAES', () {
    final subjects = EducationCatalog.subjectsFallback(gradeId: null, lang: 'es');
    expect(subjects.map((s) => s.id), containsAll(['lectora', 'm1', 'hist']));
  });
}
