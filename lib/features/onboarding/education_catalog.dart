import '../../data/models/models.dart';

/// Respaldo local del catálogo educativo.
///
/// La fuente de verdad es el backend (GET /countries, /countries/:code/grades y
/// /tests?gradeId=). Esta copia solo se usa cuando la API no responde, para que
/// el onboarding no quede bloqueado sin red. Los ids son exactamente los que
/// emite el backend (`src/data/catalog.js`); si allí cambian, hay que
/// actualizarlos aquí.
class EducationCatalog {
  EducationCatalog._();

  static const countryCl = 'CL';
  static const countryUk = 'UK';

  /// Normaliza códigos antiguos ('GB') al que usa el backend ('UK').
  static String normalizeCountry(String? code) {
    final c = (code ?? countryCl).toUpperCase();
    if (c == 'GB' || c == 'UK') return countryUk;
    return countryCl;
  }

  /// Idioma por defecto de cada país (mismo criterio que el backend).
  static String languageFor(String countryCode) =>
      normalizeCountry(countryCode) == countryUk ? 'en' : 'es';

  static List<GradeGroup> gradeGroupsFor(String countryCode, String lang) {
    final en = lang == 'en';
    if (normalizeCountry(countryCode) == countryUk) {
      return [
        GradeGroup(
          key: 'primary',
          label: 'Primary school',
          items: [for (var n = 1; n <= 6; n++) GradeOption(id: 'uk-year-$n', label: 'Year $n')],
        ),
        GradeGroup(
          key: 'secondary',
          label: 'Secondary school',
          items: [for (var n = 7; n <= 11; n++) GradeOption(id: 'uk-year-$n', label: 'Year $n')],
        ),
        const GradeGroup(
          key: 'sixth-form',
          label: 'Sixth form',
          items: [
            GradeOption(id: 'uk-year-12', label: 'Year 12'),
            GradeOption(id: 'uk-year-13', label: 'Year 13'),
          ],
        ),
        const GradeGroup(
          key: 'qualifications',
          label: 'National qualifications',
          items: [
            GradeOption(id: 'uk-gcse', label: 'GCSE', kind: 'exam'),
            GradeOption(id: 'uk-a-levels', label: 'A levels', kind: 'exam'),
          ],
        ),
      ];
    }
    return [
      GradeGroup(
        key: 'primary',
        label: en ? 'Primary education' : 'Educacion basica',
        items: [
          for (var n = 1; n <= 8; n++)
            GradeOption(id: 'cl-basic-$n', label: en ? 'Year $n' : '${n}º Basico'),
        ],
      ),
      GradeGroup(
        key: 'secondary',
        label: en ? 'Secondary education' : 'Educacion media',
        items: [
          for (var n = 1; n <= 4; n++)
            GradeOption(id: 'cl-media-$n', label: en ? 'Secondary $n' : '${n}º Medio'),
        ],
      ),
      GradeGroup(
        key: 'entrance',
        label: en ? 'University entrance' : 'Prueba de acceso',
        items: const [GradeOption(id: 'cl-paes', label: 'PAES', kind: 'exam')],
      ),
    ];
  }

  /// Asignaturas del grado. `null` o desconocido devuelve las pruebas PAES.
  static List<TestInfo> subjectsFallback({String? gradeId, required String lang}) {
    final en = lang == 'en';
    final id = gradeId ?? 'cl-paes';
    final isUk = id.startsWith('uk-');
    final isExam = id == 'cl-paes' || id == 'uk-gcse' || id == 'uk-a-levels';

    if (isUk) {
      if (isExam) {
        return [
          TestInfo(id: 'eng-lang', label: 'English Language', color: '#1A365D', hasQuestions: false),
          TestInfo(id: 'eng-lit', label: 'English Literature', color: '#10B981', hasQuestions: false),
          TestInfo(id: 'maths', label: 'Maths', color: '#6366F1', hasQuestions: false),
          TestInfo(id: 'sciences', label: 'Sciences', color: '#F5B041', hasQuestions: false),
          TestInfo(id: 'history', label: 'History', color: '#EF4444', hasQuestions: false),
        ];
      }
      return [
        TestInfo(id: 'eng', label: 'English', color: '#1A365D', hasQuestions: false),
        TestInfo(id: 'maths', label: 'Maths', color: '#10B981', hasQuestions: false),
        TestInfo(id: 'science', label: 'Science', color: '#6366F1', hasQuestions: false),
        TestInfo(id: 'history', label: 'History', color: '#F5B041', hasQuestions: false),
      ];
    }
    if (!isExam) {
      return [
        TestInfo(id: 'language', label: en ? 'Language' : 'Lenguaje', color: '#1A365D', hasQuestions: false),
        TestInfo(id: 'maths', label: en ? 'Maths' : 'Matematica', color: '#10B981', hasQuestions: false),
        TestInfo(id: 'science', label: en ? 'Science' : 'Ciencias', color: '#6366F1', hasQuestions: false),
        TestInfo(id: 'history', label: en ? 'History' : 'Historia', color: '#F5B041', hasQuestions: false),
      ];
    }
    return [
      TestInfo(id: 'lectora', label: en ? 'Reading comprehension' : 'Comp. Lectora', color: '#1A365D'),
      TestInfo(id: 'm1', label: en ? 'Maths M1' : 'Matematica M1', color: '#10B981'),
      TestInfo(id: 'm2', label: en ? 'Maths M2' : 'Matematica M2', color: '#6366F1'),
      TestInfo(id: 'cien', label: en ? 'Science' : 'Ciencias', color: '#F5B041'),
      TestInfo(id: 'hist', label: en ? 'History & social sciences' : 'Historia y C. Soc.', color: '#EF4444'),
    ];
  }
}
