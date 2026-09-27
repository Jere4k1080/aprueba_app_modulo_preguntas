import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../data/models/models.dart';
import 'app_providers.dart';
import 'data_providers.dart';

/// Estado de la sesión de práctica en curso (pregunta, selección, resultado).
class PracticeSessionState {
  const PracticeSessionState({
    this.question,
    this.quota,
    this.selectedIndex,
    this.result,
    this.elapsedMs = 0,
    this.loading = false,
    this.error,
  });

  final Question? question;

  /// Cuota del día, de meta.quota de GET /practice/next.
  final QuotaState? quota;
  final int? selectedIndex;
  final AnswerResult? result;
  final int elapsedMs;
  final bool loading;

  /// Por qué no hay pregunta: cuota, pruebas, banco vacío o red. La pantalla
  /// Pregunta lo muestra como estado (regla de negocio 8).
  final ApiException? error;

  PracticeSessionState copyWith({
    Question? question,
    int? selectedIndex,
    AnswerResult? result,
    int? elapsedMs,
    bool? loading,
    ApiException? error,
    bool clearResult = false,
    bool clearSelection = false,
  }) =>
      PracticeSessionState(
        question: question ?? this.question,
        quota: quota,
        selectedIndex: clearSelection ? null : (selectedIndex ?? this.selectedIndex),
        result: clearResult ? null : (result ?? this.result),
        elapsedMs: elapsedMs ?? this.elapsedMs,
        loading: loading ?? this.loading,
        error: error,
      );

  /// Letra (A..E) de la alternativa seleccionada.
  String? get selectedLetter =>
      selectedIndex == null ? null : String.fromCharCode(65 + selectedIndex!);
}

class PracticeSession extends Notifier<PracticeSessionState> {
  @override
  PracticeSessionState build() => const PracticeSessionState();

  /// Pide la siguiente pregunta. Un error de la API no se relanza: queda en
  /// [PracticeSessionState.error] y la pantalla Pregunta lo muestra.
  Future<void> loadNext() async {
    state = const PracticeSessionState(loading: true);
    try {
      final res = await ref.read(practiceRepositoryProvider).next();
      state = PracticeSessionState(question: res.question, quota: res.quota);
    } on ApiException catch (e) {
      state = PracticeSessionState(error: e);
    }
  }

  void select(int index) => state = state.copyWith(selectedIndex: index);
  void setElapsed(int ms) => state = state.copyWith(elapsedMs: ms);

  Future<AnswerResult> submit({String? sessionId}) async {
    final q = state.question!;
    final letter = state.selectedLetter!;
    state = state.copyWith(loading: true);
    final result = await ref.read(practiceRepositoryProvider).answer(
          questionId: q.id,
          selected: letter,
          elapsedMs: state.elapsedMs,
          sessionId: sessionId,
        );
    state = state.copyWith(result: result, loading: false);
    // Refresca cuota/perfil tras responder.
    ref.invalidate(quotaProvider);
    return result;
  }
}

final practiceSessionProvider =
    NotifierProvider<PracticeSession, PracticeSessionState>(PracticeSession.new);
