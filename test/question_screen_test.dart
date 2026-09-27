import 'dart:convert';
import 'dart:typed_data';

import 'package:aprueba_app/core/l10n/app_strings.dart';
import 'package:aprueba_app/core/network/api_client.dart';
import 'package:aprueba_app/core/network/api_exception.dart';
import 'package:aprueba_app/core/theme/app_theme.dart';
import 'package:aprueba_app/core/widgets/common_widgets.dart';
import 'package:aprueba_app/data/models/models.dart';
import 'package:aprueba_app/data/repositories/practice_repository.dart';
import 'package:aprueba_app/data/repositories/profile_repository.dart';
import 'package:aprueba_app/features/practice/question_screen.dart';
import 'package:aprueba_app/features/practice/quota_unlock_screen.dart';
import 'package:aprueba_app/providers/app_providers.dart';
import 'package:aprueba_app/providers/data_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Next = ({Question question, QuotaState? quota});

/// Entrega en orden lo que respondería GET /practice/next: una pregunta con su
/// cuota o el error de la API.
class _FakePractice implements PracticeRepository {
  _FakePractice(this.outcomes);
  final List<Object> outcomes;
  int calls = 0;

  @override
  Future<_Next> next() async {
    final outcome = outcomes[calls++];
    if (outcome is ApiException) throw outcome;
    return outcome as _Next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Guarda lo que la app envía a PUT /me/preferences.
class _FakeProfile implements ProfileRepository {
  Preferences? saved;

  @override
  Future<Preferences> setPreferences(Preferences prefs) async => saved = prefs;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Responde con el estado y el cuerpo indicados, o falla como sin red.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int? status;
  final String body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (status == null) throw DioException.connectionError(requestOptions: options, reason: 'sin red');
    return ResponseBody.fromString(body, status!, headers: {
      Headers.contentTypeHeader: [body.startsWith('{') ? Headers.jsonContentType : 'text/html'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<ApiException> _errorOf(int? status, String body) async {
  final api = ApiClient(
    idToken: ({bool forceRefresh = false}) async => null,
    dio: Dio()..httpClientAdapter = _Adapter(status, body),
  );
  try {
    await api.get('/practice/next', skipAuth: true);
  } on ApiException catch (e) {
    return e;
  }
  throw StateError('la petición no falló');
}

ApiException _api(String code, {String? field, int? status}) =>
    ApiException(code: code, message: 'Mensaje del servidor para $code.', field: field, statusCode: status);

_Next _question({required int current, int? total, required QuotaState quota}) => (
      question: Question(
        id: 'qst_4d21a90b3c',
        testId: 'm1',
        axis: 'Álgebra',
        difficulty: 'd2',
        statement: 'Si 3x + 7 = 22, ¿cuál es el valor de x?',
        options: const ['x = 3', 'x = 5', 'x = 7', 'x = 15'],
        progressCurrent: current,
        progressTotal: total,
      ),
      quota: quota,
    );

Future<_FakePractice> _pump(WidgetTester tester, List<Object> outcomes, {List<Override> extra = const []}) async {
  final practice = _FakePractice(outcomes);
  await tester.pumpWidget(ProviderScope(
    overrides: [practiceRepositoryProvider.overrideWithValue(practice), ...extra],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('es'),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const QuestionScreen(),
    ),
  ));
  // La pantalla pide la pregunta al abrirse; el segundo pump dibuja la respuesta.
  await tester.pump();
  await tester.pump();
  return practice;
}

void main() {
  group('códigos del módulo en ApiException', () {
    test('cada código lleva a su estado', () {
      expect(_api('QUOTA_BASE_REACHED').isQuotaBaseReached, isTrue);
      expect(_api('QUOTA_BASE_REACHED').isQuotaExhausted, isFalse);
      expect(_api('QUOTA_DAILY_LIMIT').isQuotaExhausted, isTrue);
      expect(_api('NO_QUESTIONS_AVAILABLE', field: 'selectedTests').needsTests, isTrue);
      final empty = _api('NO_QUESTIONS_AVAILABLE');
      expect(empty.isNoQuestions && !empty.needsTests, isTrue);
      expect(ApiException.network().isNetwork, isTrue);
    });

    test('sin conexión solo cuando falla la red: un 404 o un 401 traen respuesta', () async {
      final envelope = jsonEncode({
        'data': null,
        'error': {'code': 'NOT_FOUND', 'message': 'El recurso solicitado no existe.'},
        'meta': null,
      });
      final notFound = await _errorOf(404, envelope);
      expect((notFound.code, notFound.isNetwork), ('NOT_FOUND', false));
      final html = await _errorOf(404, '<html>Not Found</html>');
      expect((html.code, html.isNetwork), ('HTTP_404', false));
      final platform401 = await _errorOf(401, '<html>Authentication Required</html>');
      expect((platform401.code, platform401.isNetwork), ('HTTP_401', false));
      expect((await _errorOf(null, '')).isNetwork, isTrue);
    });
  });

  group('plan ilimitado', () {
    test('Question conserva progress.total en null y User lee quota.unlimited', () {
      final q = Question.fromJson({
        'id': 'qst_1',
        'testId': 'm1',
        'statement': 's',
        'options': ['a', 'b'],
        'progress': {'current': 51, 'total': null},
      });
      expect((q.progressCurrent, q.progressTotal), (51, null));
      final u = User.fromJson({
        'id': 'usr_1',
        'name': 'Camila',
        'plan': 'all',
        'quota': {'used': 50, 'max': 0, 'unlimited': true},
      });
      expect((u.quotaUnlimited, u.quotaMax), (true, 0));
      // La caché de GET /me guarda toJson: unlimited no se pierde al leerla.
      expect(User.fromJson(u.toJson()).quotaUnlimited, isTrue);
    });

    testWidgets('la pantalla revisa unlimited antes que max', (tester) async {
      await _pump(tester, [_question(current: 51, quota: QuotaState(used: 50, max: 0, unlimited: true))]);
      expect(find.text('Pregunta 51'), findsOneWidget);
      expect(find.text('Cuota diaria: ∞'), findsOneWidget);
      expect(find.textContaining('de 0'), findsNothing);
      expect(find.byType(ProgressBar), findsNothing);
    });
  });

  testWidgets('muestra enunciado, alternativas, cronómetro, progreso y la cuota de meta', (tester) async {
    await _pump(tester, [_question(current: 6, total: 10, quota: QuotaState(used: 5, max: 10))]);
    expect(find.text('Pregunta 6 de 10'), findsOneWidget);
    expect(find.text('Cuota diaria: 5/10'), findsOneWidget);
    expect(find.text('Si 3x + 7 = 22, ¿cuál es el valor de x?'), findsOneWidget);
    for (final option in ['x = 3', 'x = 5', 'x = 7', 'x = 15']) {
      expect(find.text(option), findsOneWidget);
    }
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget);
  });

  group('errores de negocio como estados', () {
    testWidgets('QUOTA_BASE_REACHED lleva a la pantalla de desbloqueo', (tester) async {
      await _pump(tester, [_api('QUOTA_BASE_REACHED', status: 422)]);
      expect(find.byType(QuotaUnlockScreen), findsOneWidget);
    });

    testWidgets('QUOTA_DAILY_LIMIT muestra el límite diario', (tester) async {
      await _pump(tester, [_api('QUOTA_DAILY_LIMIT', status: 422)]);
      expect(find.text('Llegaste al límite diario'), findsOneWidget);
      expect(find.text('Elegir plan'), findsOneWidget);
    });

    testWidgets('NO_QUESTIONS_AVAILABLE sin field muestra el estado vacío', (tester) async {
      await _pump(tester, [_api('NO_QUESTIONS_AVAILABLE', status: 404)]);
      expect(find.text('No quedan preguntas'), findsOneWidget);
    });

    testWidgets('sin pruebas elegidas invita a elegirlas y guarda la elección', (tester) async {
      final profile = _FakeProfile();
      final practice = await _pump(tester, [
        _api('NO_QUESTIONS_AVAILABLE', field: 'selectedTests', status: 404),
        _question(current: 1, total: 10, quota: QuotaState(used: 0, max: 10)),
      ], extra: [
        profileRepositoryProvider.overrideWithValue(profile),
        preferencesProvider.overrideWith((ref) async => const Preferences(difficulty: 'd2')),
        testsProvider.overrideWith((ref) async => [
              TestInfo(id: 'm1', label: 'Matemática M1', color: '#10B981'),
              TestInfo(id: 'hist', label: 'Historia', color: '#EF4444', hasQuestions: false),
            ]),
      ]);
      expect(find.text('Elige al menos una prueba para recibir preguntas.'), findsOneWidget);
      await tester.tap(find.text('Elegir pruebas'));
      // La hoja sube con una animación y espera las preferencias y el catálogo.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Historia'), findsNothing, reason: 'una prueba sin preguntas no se ofrece');
      await tester.tap(find.text('Matemática M1'));
      await tester.pump();
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(profile.saved?.selectedTests, ['m1']);
      expect(profile.saved?.difficulty, 'd2', reason: 'conserva el resto de las preferencias');
      expect(practice.calls, 2, reason: 'después de guardar pide la pregunta otra vez');
      expect(find.text('Pregunta 1 de 10'), findsOneWidget);
    });

    testWidgets('sin red muestra sin conexión y reintenta', (tester) async {
      final practice = await _pump(tester, [
        ApiException.network(),
        _question(current: 1, total: 10, quota: QuotaState(used: 0, max: 10)),
      ]);
      expect(find.text('Sin conexión. Revisa tu red e intenta de nuevo.'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();
      expect(practice.calls, 2);
      expect(find.text('Pregunta 1 de 10'), findsOneWidget);
    });

    testWidgets('un 404 no se muestra como sin conexión', (tester) async {
      await _pump(tester, [_api('NOT_FOUND', status: 404)]);
      expect(find.text('Mensaje del servidor para NOT_FOUND.'), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsNothing);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
    });
  });
}
