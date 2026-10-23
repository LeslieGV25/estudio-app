import 'dart:io';
import 'dart:math';

import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/exam/domain/exam_plan.dart';
import 'package:estudio_app/features/exam/domain/exam_session_config.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/exam/domain/usecases/start_exam.dart';
import 'package:estudio_app/features/exam/domain/usecases/submit_exam_part.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/pack_providers.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/data/review_providers.dart';
import 'package:estudio_app/features/review/domain/usecases/sync_review_state.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/review.dart';
import '../../../helpers/test_database.dart';

/// Estadísticas sobre el pack `completo` (instalado como pack incluido):
/// tema 1 (e1-01; e1-03 obsoleta), tema 2 (e1-r1; e1-02 anulada) y tema 3
/// (e2-01, est-01).
void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  const packId = 'test-completo';
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = cal.at(2026, 10, 23, 10);
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  /// Una práctica de ayer: e1-01 diez veces con 2 aciertos (tema 1, débil)
  /// y e2-01 bien (tema 3). El tema 2 queda sin practicar.
  Future<void> practicedYesterday() async {
    final progress = DriftProgressRepository(
      db,
      clock: () => now.subtract(const Duration(days: 1)),
    );
    final session = await progress.startSession(
      packId: packId,
      mode: SessionMode.practice,
      config: const {},
    );
    for (var i = 0; i < 10; i++) {
      await progress.recordAnswer(
        sessionId: session.id,
        questionId: 'e1-01',
        chosen: i < 2 ? 'b' : 'a',
        isCorrect: i < 2,
        timeMs: 1000,
      );
    }
    await progress.recordAnswer(
      sessionId: session.id,
      questionId: 'e2-01',
      chosen: 'b',
      isCorrect: true,
      timeMs: 1000,
    );
  }

  /// Simulacro completo del examen 2026, todo bien (ej1: 10,000; ej2: 1,00).
  /// Con la app ya arrancada: el pack lo ha instalado ella.
  Future<void> examDone() async {
    final content = DriftPackContentRepository(db);
    final progress = DriftProgressRepository(db, clock: () => now);
    final start = StartExam(progress);
    final submit = SubmitExamPart(
      content,
      progress,
      SyncReviewState(progress, DriftReviewRepository(db), cal),
    );
    Future<void> answer(String sessionId, Map<String, String> choices) async {
      var config = ExamSessionConfig.fromJson(
        (await progress.findSession(sessionId))!.config,
      );
      for (final MapEntry(:key, :value) in choices.entries) {
        config = config.withChoice(key, value);
      }
      await progress.updateSessionConfig(sessionId, config.toJson());
      await submit(sessionId);
    }

    final plan = ExamPlan.build(
      questions: await content.questions(packId),
      outline: await content.outline(packId),
      rules: await content.examRules(packId),
      setup: const ExamSetup(kind: ExamKind.realExam, sourceId: 'examen-2026'),
      random: Random(1),
    );
    final first = (await start(packId, plan))!;
    await answer(first.id, {'e1-01': 'b', 'e1-r1': 'b'});
    final second = (await start.next((await progress.findSession(first.id))!))!;
    await answer(second.id, {'e2-01': 'b'});
  }

  /// Arranca la app (instala y activa el pack); [before] siembra datos con
  /// el pack ya instalado. Después abre las estadísticas.
  Future<void> openStats(
    WidgetTester tester, {
    Future<void> Function()? before,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bundledPackLoaderProvider.overrideWithValue(
            () async => File(completoPath).readAsBytesSync(),
          ),
          clockProvider.overrideWithValue(() => now),
          reviewCalendarProvider.overrideWithValue(cal),
        ],
        child: const EstudioApp(),
      ),
    );
    await settle(tester);
    if (before != null) await tester.runAsync(before);
    await tapAndSettle(tester, find.text('Estadísticas'));
  }

  testWidgets('resumen: tema débil, tema sin practicar y «Practicar este '
      'tema» abre la práctica con el tema marcado', (tester) async {
    await practicedYesterday();
    await openStats(tester);

    // 3 aciertos de 11.
    expect(find.text('27 %'), findsOneWidget);
    expect(find.text('de aciertos en 11 respuestas'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Últimos 30 días: 11 respuestas en 1 día, 27 % de aciertos.',
      ),
      findsOneWidget,
    );

    // Débil: tema 1 (20 %). Sin practicar: tema 2.
    expect(find.text('Tema 1 · Constitución'), findsOneWidget);
    expect(find.text('20 % de aciertos · 10 respuestas'), findsOneWidget);
    expect(find.text('Tema 2 · Redes'), findsOneWidget);
    expect(find.text('1 pregunta'), findsOneWidget);

    final practiceTopic2 = find.descendant(
      of: find.ancestor(
        of: find.text('Tema 2 · Redes'),
        matching: find.byType(Card),
      ),
      matching: find.text('Practicar este tema'),
    );
    await tapAndSettle(tester, practiceTopic2);

    expect(find.text('Practicar'), findsWidgets);
    // Tema 2: e1-r1 (e1-02 está anulada).
    expect(find.text('1 pregunta disponible'), findsOneWidget);
    final checkbox = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Tema 2. Redes'),
    );
    expect(checkbox.value, isTrue);
  });

  testWidgets('el filtro cambia los datos', (tester) async {
    await practicedYesterday();
    await openStats(tester);

    // Sin ensureVisible: «Cambiar» está a la derecha de una página del
    // TabBarView (un PageView horizontal), y ensureVisible lo alinearía al
    // borde izquierdo, cambiando de pestaña.
    await tester.tap(find.text('Cambiar'));
    await settle(tester);
    await tapAndSettle(tester, find.widgetWithText(FilterChip, 'Práctica'));
    // Sin práctica no queda ninguna respuesta.
    Navigator.pop(tester.element(find.text('Fuentes')));
    await settle(tester);

    expect(find.text('Simulacro y repaso · todas las fuentes'), findsOneWidget);
    expect(
      find.text('Todavía no hay respuestas con estos filtros.'),
      findsOneWidget,
    );
    // Los temas sin practicar se siguen viendo.
    expect(find.text('Tema 1 · Constitución'), findsOneWidget);
  });

  testWidgets('temas: bloques con sus temas y la cobertura', (tester) async {
    await practicedYesterday();
    await openStats(tester);

    await tapAndSettle(tester, find.text('Temas'));
    await tapAndSettle(tester, find.text('Bloque técnico'));

    // Tema 3: e2-01 vista; est-01 no.
    expect(
      find.text('100 % de aciertos · 1 respuesta · vistas 1 de 2 (50 %)'),
      findsOneWidget,
    );
    expect(find.text('Sin practicar · vistas 0 de 1 (0 %)'), findsOneWidget);
  });

  testWidgets('simulacros: sin ninguno, invita a hacer uno', (tester) async {
    await openStats(tester);

    await tapAndSettle(tester, find.text('Simulacros'));

    expect(find.text('Aún no has hecho ningún simulacro.'), findsOneWidget);
  });

  testWidgets('simulacros: gráfico, lista y abrir el resultado', (
    tester,
  ) async {
    await openStats(tester, before: examDone);

    await tapAndSettle(tester, find.text('Simulacros'));

    expect(find.byType(LineChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Primer ejercicio: 1 nota, la última 10,000. '
        'Segundo ejercicio: 1 nota, la última 1,00',
      ),
      findsOneWidget,
    );
    expect(find.text('Examen real · Examen 2026 · completo'), findsOneWidget);
    // La hora se muestra en la zona del dispositivo (distinta en el CI): se
    // comprueban solo las notas.
    expect(
      find.textContaining(
        'Primer ejercicio: 10,000 · APTO\n'
        'Segundo ejercicio: 1,00 · APTO',
      ),
      findsOneWidget,
    );

    await tapAndSettle(
      tester,
      find.text('Examen real · Examen 2026 · completo'),
    );

    expect(find.text('Resultado del simulacro'), findsOneWidget);
  });
}
