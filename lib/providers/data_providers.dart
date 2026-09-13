import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/models.dart';
import 'app_providers.dart';

// Perfil y práctica
// Depende de la sesion: sin ella /me responde 401 y, al no recargarse, el error
// quedaba cacheado tras el login (y con el plan desconocido no aparecia Tutores).
final meProvider = FutureProvider<User>((ref) {
  ref.watch(isLoggedInProvider);
  return ref.watch(profileRepositoryProvider).me();
});

/// Plan de pago activo. Gobierna la pestaña de Tutores y el análisis de
/// falencias (el backend responde 403 PLAN_REQUIRED al plan free).
final isPaidPlanProvider =
    Provider<bool>((ref) => ref.watch(meProvider).valueOrNull?.isPaid ?? false);
final quotaProvider = FutureProvider<QuotaState>((ref) => ref.watch(profileRepositoryProvider).quota());
final progressProvider =
    FutureProvider<List<ProgressItem>>((ref) => ref.watch(profileRepositoryProvider).progress());
final testsProvider =
    FutureProvider<List<TestInfo>>((ref) => ref.watch(profileRepositoryProvider).tests());
final preferencesProvider =
    FutureProvider<Preferences>((ref) => ref.watch(profileRepositoryProvider).getPreferences());

// Medallas
final medalWalletProvider =
    FutureProvider<MedalWalletState>((ref) => ref.watch(medalsRepositoryProvider).wallet());
final giftStateProvider =
    FutureProvider<GiftState>((ref) => ref.watch(medalsRepositoryProvider).gifts());
final benefitsProvider =
    FutureProvider<List<Benefit>>((ref) => ref.watch(medalsRepositoryProvider).benefits());

// Grupos
final groupsProvider = FutureProvider<List<Group>>((ref) => ref.watch(groupsRepositoryProvider).list());
final groupDetailProvider =
    FutureProvider.family<Group, String>((ref, id) => ref.watch(groupsRepositoryProvider).detail(id));
final groupStatsProvider =
    FutureProvider.family<GroupStats, String>((ref, id) => ref.watch(groupsRepositoryProvider).stats(id));

// Comunidad
final feedProvider = FutureProvider<List<Post>>((ref) async =>
    (await ref.watch(communityRepositoryProvider).feed()).posts);

// Suscripción
final plansProvider = FutureProvider<List<Plan>>((ref) => ref.watch(subscriptionRepositoryProvider).plans());
final subscriptionProvider =
    FutureProvider<Subscription?>((ref) => ref.watch(subscriptionRepositoryProvider).current());

// Ajustes y correcciones
final correctionsProvider =
    FutureProvider<List<Correction>>((ref) => ref.watch(practiceRepositoryProvider).corrections());
