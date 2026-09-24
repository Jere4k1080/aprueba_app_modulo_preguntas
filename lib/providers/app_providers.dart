import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../data/local/database.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/community_repository.dart';
import '../data/repositories/groups_repository.dart';
import '../data/repositories/medals_repository.dart';
import '../data/repositories/notifications_repository.dart';
import '../data/repositories/practice_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/subscription_repository.dart';
import '../data/repositories/tutors_repository.dart';
import '../data/services/phone_auth_service.dart';
import '../data/services/push_service.dart';
import '../data/services/social_auth_service.dart';
import '../data/services/stripe_service.dart';
import 'auth_controller.dart';
import 'local_prefs.dart';

export 'local_prefs.dart';

/// Base de datos local (caché). Se sobreescribe en main() con la instancia abierta.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError(
    'databaseProvider debe sobreescribirse en main() con AppDatabase()'));

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

/// Estado de sesión global. El interceptor lo apaga si Firebase no logra
/// renovar el token o la API lo rechaza también renovado.
final isLoggedInProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    idToken: ({bool forceRefresh = false}) async =>
        FirebaseAuth.instance.currentUser?.getIdToken(forceRefresh),
    language: () => ref.read(localPrefsProvider).locale,
    // El mismo logout del botón: además de cerrar Firebase, borra la caché de
    // Drift, donde CachedQuestions guarda correctAnswer después de responder.
    // La bandera baja antes del logout asíncrono: los 401 simultáneos y el /me
    // que dispara logout al invalidar meProvider salen aquí sin repetirlo.
    onSessionExpired: () {
      if (!ref.read(isLoggedInProvider)) return;
      ref.read(isLoggedInProvider.notifier).state = false;
      ref.read(authControllerProvider.notifier).logout();
    },
  );
});

// ---- Repositorios ----
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(secureStorageProvider),
      ref.watch(databaseProvider),
    ));

final profileRepositoryProvider = Provider<ProfileRepository>((ref) =>
    ProfileRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) =>
    PracticeRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));

final medalsRepositoryProvider =
    Provider<MedalsRepository>((ref) => MedalsRepository(ref.watch(apiClientProvider)));

final groupsRepositoryProvider =
    Provider<GroupsRepository>((ref) => GroupsRepository(ref.watch(apiClientProvider)));

final communityRepositoryProvider =
    Provider<CommunityRepository>((ref) => CommunityRepository(ref.watch(apiClientProvider)));

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
    (ref) => SubscriptionRepository(ref.watch(apiClientProvider)));

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(apiClientProvider)));

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
    (ref) => NotificationsRepository(ref.watch(apiClientProvider)));

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) =>
    CatalogRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));

final tutorsRepositoryProvider =
    Provider<TutorsRepository>((ref) => TutorsRepository(ref.watch(apiClientProvider)));

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository(ref.watch(apiClientProvider)));

// ---- Servicios ----
final socialAuthServiceProvider =
    Provider<SocialAuthService>((ref) => SocialAuthService());
final phoneAuthServiceProvider =
    Provider<PhoneAuthService>((ref) => PhoneAuthService());
final stripeServiceProvider = Provider<StripeService>((ref) => StripeService());
final pushServiceProvider = Provider<PushService>(
    (ref) => PushService(ref.watch(notificationsRepositoryProvider)));
