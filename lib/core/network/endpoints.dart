/// Rutas relativas a la raíz versionada (AppConfig.apiBaseUrl).
class Endpoints {
  Endpoints._();

  // Auth & cuenta
  static const register = '/auth/register';
  static const loginEp = '/auth/login';
  static const social = '/auth/social';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const passwordForgot = '/auth/password/forgot';
  static const passwordReset = '/auth/password/reset';
  static const phoneVerificationStart = '/auth/phone/send-code';
  static const phoneVerificationConfirm = '/auth/phone/verify-code';
  static const me = '/me';
  static const mePhone = '/me/phone';
  static const meSettings = '/me/settings';
  static const meDataExport = '/me/data-export';

  // Onboarding
  static const countries = '/countries';
  static String countryGrades(String code) => '/countries/$code/grades';
  static const tests = '/tests';
  static String testsForGrade(String gradeId) => '/tests?gradeId=$gradeId';
  static const mePreferences = '/me/preferences';

  // Práctica
  static const practiceNext = '/practice/next';
  static String question(String id) => '/questions/$id';
  static String answer(String id) => '/questions/$id/answer';
  static String explanation(String id) => '/questions/$id/explanation';
  static String skill(String id) => '/questions/$id/skill';
  static const meQuota = '/me/quota';
  static const meQuotaUnlock = '/me/quota/unlock';
  static const meProgress = '/me/progress';
  static const corrections = '/corrections';
  static String correction(String id) => '/corrections/$id';

  // Medallas
  static const meMedals = '/me/medals';
  static const medalsExchange = '/me/medals/exchange';
  static const meGifts = '/me/gifts';
  static const benefits = '/benefits';
  static String benefit(String id) => '/benefits/$id';
  static String benefitRedeem(String id) => '/benefits/$id/redeem';

  // Grupos
  static const groups = '/groups';
  static String group(String id) => '/groups/$id';
  static String groupInvitations(String id) => '/groups/$id/invitations';
  static String invitationAccept(String token) => '/invitations/$token/accept';
  static String groupMember(String id, String userId) =>
      '/groups/$id/members/$userId';
  static String groupLeave(String id) => '/groups/$id/members/me';
  static String groupStats(String id) => '/groups/$id/stats';
  static String groupShared(String id) => '/groups/$id/shared';

  // Comunidad
  static const feed = '/feed';
  static const posts = '/posts';
  static String post(String id) => '/posts/$id';
  static String postLike(String id) => '/posts/$id/like';
  static String postRepost(String id) => '/posts/$id/repost';
  static String postComments(String id) => '/posts/$id/comments';
  static String postComment(String postId, String commentId) =>
      '/posts/$postId/comments/$commentId';

  // Tutores (marketplace)
  static const tutors = '/tutors';
  static const tutorsFeatured = '/tutors/featured';
  static String tutor(String id) => '/tutors/$id';
  static String tutorReviews(String id) => '/tutors/$id/reviews';
  static String tutorContactRequests(String id) => '/tutors/$id/contact-requests';
  static const meGapAnalysis = '/me/gap-analysis';

  // Chat con tutores
  static const meConversations = '/me/conversations';
  static String conversation(String id) => '/conversations/$id';
  static String conversationMessages(String id) => '/conversations/$id/messages';
  static String conversationRead(String id) => '/conversations/$id/read';
  static String conversationContactSharing(String id) =>
      '/conversations/$id/contact-sharing';

  // Planes y pagos
  static const plans = '/plans';
  static const checkoutSessions = '/checkout/sessions';
  static String checkoutSessionConfirm(String id) =>
      '/checkout/sessions/$id/confirm';
  static const meSubscription = '/me/subscription';
  static const subscriptionChange = '/me/subscription/change';
  static const subscriptionCancel = '/me/subscription/cancel';
  static const meInvoices = '/me/invoices';

  // Notificaciones y dispositivos
  static const devices = '/devices';
  static String device(String id) => '/devices/$id';
  static const meNotifications = '/me/notifications';
  static String notificationRead(String id) => '/me/notifications/$id/read';
  static const notificationsReadAll = '/me/notifications/read-all';
  static const notificationPreferences = '/me/notifications/preferences';
}
