import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/community/feed_screen.dart';
import '../../features/groups/create_group_screen.dart';
import '../../features/groups/group_detail_screen.dart';
import '../../features/groups/group_stats_screen.dart';
import '../../features/groups/groups_screen.dart';
import '../../features/groups/invite_members_screen.dart';
import '../../features/groups/share_group_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/medals/benefits_screen.dart';
import '../../features/medals/exchange_screen.dart';
import '../../features/medals/gift_screen.dart';
import '../../features/medals/medals_screen.dart';
import '../../features/onboarding/format_screen.dart';
import '../../features/onboarding/select_tests_screen.dart';
import '../../features/onboarding/setup_screens.dart';
import '../../features/practice/correction_screen.dart';
import '../../features/practice/explanation_screen.dart';
import '../../features/practice/question_screen.dart';
import '../../features/practice/quota_unlock_screen.dart';
import '../../features/practice/result_screen.dart';
import '../../features/practice/skill_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/subscription/checkout_screen.dart';
import '../../features/subscription/manage_plan_screen.dart';
import '../../features/subscription/paywall_screen.dart';
import '../../features/subscription/payment_success_screen.dart';
import '../../features/tutors/gap_analysis_screen.dart';
import '../../features/tutors/tutor_chat_screen.dart';
import '../../features/tutors/tutor_contact_screen.dart';
import '../../features/tutors/tutor_profile_screen.dart';
import '../../features/tutors/tutor_review_screen.dart';
import '../../features/tutors/tutors_screen.dart';
import '../../features/common/tab_scaffold.dart';
import '../../providers/app_providers.dart';
import '../../providers/data_providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// OJO: este provider NO debe hacer ref.watch de la sesion ni del plan. Si lo
/// hiciera, cada cambio construiria un GoRouter nuevo y la navegacion se
/// reiniciaria en /splash (p. ej. al registrarse, perdiendo el paso de formato).
/// El estado se lee dentro de `redirect` y `refreshListenable` lo reevalua.
final routerProvider = Provider<GoRouter>((ref) {
  const publicRoutes = {
    '/splash',
    '/register',
    '/login',
    '/forgot',
    '/onboarding/phone',
    '/onboarding/verify-phone',
    '/onboarding/locale',
    '/onboarding/grade',
    '/onboarding/tests',
    '/onboarding/account',
    '/onboarding/format',
  };
  const phoneRoutes = {'/register', '/onboarding/phone', '/onboarding/verify-phone'};

  final refresh = _RefreshOn(ref);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      final me = ref.read(meProvider);
      final loc = state.matchedLocation;
      final isPublic = publicRoutes.contains(loc);
      if (!loggedIn && !isPublic) return '/splash';
      if (loggedIn && (loc == '/splash' || loc == '/login' || loc == '/register')) {
        return '/home';
      }
      // Sin verificación por SMS el registro empieza en país e idioma.
      if (!AppConfig.phoneVerificationEnabled && phoneRoutes.contains(loc)) {
        return '/onboarding/locale';
      }
      // Tutores es una función de pago. Mientras /me no haya resuelto no se
      // conoce el plan: no redirigimos para no expulsar a un usuario de pago.
      final planKnown = me.hasValue;
      final isPaid = me.valueOrNull?.isPaid ?? false;
      if (loggedIn && planKnown && !isPaid && loc.startsWith('/tutors')) return '/paywall';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/register', builder: (_, __) => const PhoneNumberScreen()),
      GoRoute(path: '/onboarding/phone', builder: (_, __) => const PhoneNumberScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/onboarding/verify-phone', builder: (_, __) => const VerifyPhoneScreen()),
      GoRoute(path: '/onboarding/locale', builder: (_, __) => const LocaleConfirmationScreen()),
      GoRoute(path: '/onboarding/grade', builder: (_, __) => const EducationStageScreen()),
      GoRoute(path: '/onboarding/tests', builder: (_, __) => const SelectTestsScreen()),
      GoRoute(path: '/onboarding/account', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/onboarding/format', builder: (_, __) => const FormatScreen()),

      // Shell de pestañas
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => TabScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/medals', builder: (_, __) => const MedalsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/tutors', builder: (_, __) => const TutorsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/feed', builder: (_, __) => const FeedScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())]),
        ],
      ),

      // Práctica
      GoRoute(path: '/practice/question', parentNavigatorKey: _rootKey, builder: (_, __) => const QuestionScreen()),
      GoRoute(path: '/practice/result', parentNavigatorKey: _rootKey, builder: (_, __) => const ResultScreen()),
      GoRoute(path: '/practice/explanation', parentNavigatorKey: _rootKey, builder: (_, __) => const ExplanationScreen()),
      GoRoute(path: '/practice/skill', parentNavigatorKey: _rootKey, builder: (_, __) => const SkillScreen()),
      GoRoute(path: '/practice/correction', parentNavigatorKey: _rootKey, builder: (_, __) => const CorrectionScreen()),
      GoRoute(path: '/practice/quota', parentNavigatorKey: _rootKey, builder: (_, __) => const QuotaUnlockScreen()),

      // Medallas
      GoRoute(path: '/medals/exchange', parentNavigatorKey: _rootKey, builder: (_, __) => const ExchangeScreen()),
      GoRoute(path: '/medals/gift', parentNavigatorKey: _rootKey, builder: (_, __) => const GiftScreen()),
      GoRoute(path: '/medals/benefits', parentNavigatorKey: _rootKey, builder: (_, __) => const BenefitsScreen()),

      // Grupos
      GoRoute(path: '/groups/create', parentNavigatorKey: _rootKey, builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
          path: '/groups/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => GroupDetailScreen(groupId: s.pathParameters['id']!)),
      GoRoute(
          path: '/groups/:id/invite',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => InviteMembersScreen(groupId: s.pathParameters['id']!)),
      GoRoute(
          path: '/groups/:id/stats',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => GroupStatsScreen(groupId: s.pathParameters['id']!)),
      GoRoute(path: '/share-group', parentNavigatorKey: _rootKey, builder: (_, __) => const ShareGroupScreen()),

      // Tutores (marketplace, chat y análisis de falencias)
      GoRoute(path: '/tutors/analysis', parentNavigatorKey: _rootKey, builder: (_, __) => const GapAnalysisScreen()),
      GoRoute(path: '/tutors/chats', parentNavigatorKey: _rootKey, builder: (_, __) => const TutorChatsScreen()),
      GoRoute(
          path: '/tutors/chats/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => TutorChatScreen(conversationId: s.pathParameters['id']!)),
      GoRoute(
          path: '/tutors/:id',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => TutorProfileScreen(tutorId: s.pathParameters['id']!)),
      GoRoute(
          path: '/tutors/:id/reviews',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => TutorReviewsScreen(tutorId: s.pathParameters['id']!)),
      GoRoute(
          path: '/tutors/:id/contact',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => TutorContactScreen(tutorId: s.pathParameters['id']!)),
      GoRoute(
          path: '/tutors/:id/review',
          parentNavigatorKey: _rootKey,
          builder: (_, s) => TutorReviewScreen(tutorId: s.pathParameters['id']!)),

      // Suscripción
      GoRoute(path: '/paywall', parentNavigatorKey: _rootKey, builder: (_, __) => const PaywallScreen()),
      GoRoute(
          path: '/checkout',
          parentNavigatorKey: _rootKey,
          builder: (_, s) {
            final extra = s.extra as Map<String, dynamic>?;
            return CheckoutScreen(
              planId: extra?['plan'] as String? ?? 'all',
              billingCycle: extra?['cycle'] as String? ?? 'yearly',
            );
          }),
      GoRoute(path: '/pay-success', parentNavigatorKey: _rootKey, builder: (_, __) => const PaymentSuccessScreen()),
      GoRoute(path: '/manage-plan', parentNavigatorKey: _rootKey, builder: (_, __) => const ManagePlanScreen()),
    ],
  );
  ref.onDispose(() {
    // Primero el router (deja de escuchar) y luego el listenable.
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Notifica al router cuando cambia el estado de sesión.
class _RefreshOn extends ChangeNotifier {
  _RefreshOn(Ref ref) {
    ref.listen(isLoggedInProvider, (_, __) => notifyListeners());
    // Al cambiar de plan aparece/desaparece la pestaña de Tutores.
    ref.listen(isPaidPlanProvider, (_, __) => notifyListeners());
  }
}
