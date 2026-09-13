import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/models/models.dart';
import '../data/repositories/tutors_repository.dart';
import 'app_providers.dart';

/// Filtros activos del marketplace (búsqueda, asignatura, modalidad, orden).
class TutorFiltersNotifier extends Notifier<TutorFilters> {
  @override
  TutorFilters build() => const TutorFilters();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setSort(String sort) => state = state.copyWith(sort: sort);
  void setVerifiedOnly(bool value) => state = state.copyWith(verifiedOnly: value);

  void toggleSubject(String subject) => state = state.subject == subject
      ? state.copyWith(clearSubject: true)
      : state.copyWith(subject: subject);

  /// Fija la asignatura sin alternar (lo usa el analisis de falencias).
  void setSubject(String subject) => state = state.copyWith(subject: subject);

  void toggleMode(String mode) =>
      state = state.mode == mode ? state.copyWith(clearMode: true) : state.copyWith(mode: mode);

  void clear() => state = const TutorFilters();
}

final tutorFiltersProvider =
    NotifierProvider<TutorFiltersNotifier, TutorFilters>(TutorFiltersNotifier.new);

final tutorsProvider = FutureProvider<List<Tutor>>((ref) {
  final filters = ref.watch(tutorFiltersProvider);
  return ref.watch(tutorsRepositoryProvider).list(filters);
});

final featuredTutorsProvider =
    FutureProvider<List<Tutor>>((ref) => ref.watch(tutorsRepositoryProvider).featured());

final tutorDetailProvider = FutureProvider.family<Tutor, String>(
    (ref, id) => ref.watch(tutorsRepositoryProvider).detail(id));

final tutorReviewsProvider = FutureProvider.family<TutorReviewPage, String>(
    (ref, id) => ref.watch(tutorsRepositoryProvider).reviews(id));

/// Premium: 403 PLAN_REQUIRED si el plan es free.
final gapAnalysisProvider =
    FutureProvider<GapAnalysis>((ref) => ref.watch(tutorsRepositoryProvider).gapAnalysis());

// ── Chat ────────────────────────────────────────────────────────────────────

final conversationsProvider =
    FutureProvider<List<Conversation>>((ref) => ref.watch(chatRepositoryProvider).conversations());

final conversationDetailProvider = FutureProvider.family<ConversationDetail, String>(
    (ref, id) => ref.watch(chatRepositoryProvider).detail(id));

/// Mensajes con polling: se refresca cada AppConfig.chatPollInterval mientras la
/// pantalla del chat está montada (el backend no expone websockets).
// autoDispose: al cerrar el chat se cancela el Timer y se libera el stream.
final conversationMessagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, conversationId) {
  final repo = ref.watch(chatRepositoryProvider);
  final controller = StreamController<List<ChatMessage>>();
  Timer? timer;
  var closed = false;
  var delivered = false;

  Future<void> tick() async {
    if (closed) return;
    try {
      final messages = await repo.messages(conversationId);
      if (closed) return;
      delivered = true;
      controller.add(messages);
    } catch (e, st) {
      // El primer fallo se propaga para mostrar el estado de error; los
      // siguientes se ignoran para que un corte momentáneo no vacíe el chat.
      if (!closed && !delivered) controller.addError(e, st);
    }
  }

  tick();
  timer = Timer.periodic(AppConfig.chatPollInterval, (_) => tick());

  ref.onDispose(() {
    closed = true;
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Número total de mensajes sin leer (badge del chat).
final unreadMessagesProvider = Provider<int>((ref) {
  final convs = ref.watch(conversationsProvider);
  return convs.valueOrNull?.fold<int>(0, (sum, c) => sum + c.unreadCount) ?? 0;
});
