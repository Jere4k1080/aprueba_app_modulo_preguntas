import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import '../features/onboarding/education_catalog.dart';
import 'app_providers.dart';

/// Catálogo del onboarding servido por el backend, con respaldo local.
///
/// Si /countries, /countries/:code/grades o /tests fallan (sin red o backend
/// caído) se usa EducationCatalog para que el alta no quede bloqueada. Los ids
/// del respaldo son los mismos que emite el backend.

const _fallbackCountries = <Country>[
  Country(code: 'CL', name: 'Chile', dialCode: '+56', flag: '🇨🇱', languages: ['es', 'en'], defaultLanguage: 'es'),
  Country(code: 'UK', name: 'Reino Unido', dialCode: '+44', flag: '🇬🇧', languages: ['en', 'es'], defaultLanguage: 'en'),
];

/// Idioma con el que se piden las etiquetas del catálogo.
final catalogLangProvider = Provider<String>((ref) => ref.watch(localPrefsProvider).locale);

final countriesProvider = FutureProvider<List<Country>>((ref) async {
  final lang = ref.watch(catalogLangProvider);
  try {
    final list = await ref.watch(catalogRepositoryProvider).countries(lang: lang);
    return list.isEmpty ? _fallbackCountries : list;
  } catch (_) {
    return _fallbackCountries;
  }
});

final gradesProvider = FutureProvider.family<List<GradeGroup>, String>((ref, countryCode) async {
  final lang = ref.watch(catalogLangProvider);
  try {
    final list = await ref.watch(catalogRepositoryProvider).grades(countryCode, lang: lang);
    if (list.isNotEmpty) return list;
  } catch (_) {/* respaldo local */}
  return EducationCatalog.gradeGroupsFor(countryCode, lang);
});

/// Asignaturas del grado elegido (pantalla select-tests).
final subjectsProvider = FutureProvider.family<List<TestInfo>, String?>((ref, gradeId) async {
  final lang = ref.watch(catalogLangProvider);
  try {
    final list = await ref.watch(catalogRepositoryProvider).subjects(gradeId: gradeId, lang: lang);
    if (list.isNotEmpty) return list;
  } catch (_) {/* respaldo local */}
  return EducationCatalog.subjectsFallback(gradeId: gradeId, lang: lang);
});
