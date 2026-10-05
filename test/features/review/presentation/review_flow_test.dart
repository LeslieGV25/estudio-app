import 'dart:io';

import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/packs/data/pack_providers.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/review/data/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/review.dart';
import '../../../helpers/test_database.dart';

/// Flujo de repaso sobre el pack `completo` (instalado como pack incluido).
/// e1-01: «¿En qué año se aprobó la Constitución española?» (b = 1978).
/// e1-r1: «¿Qué puerto usa HTTPS por defecto?» (b = 443).
void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  const packId = 'test-completo';
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = cal.at(2026, 10, 5, 10);
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

  /// Respuestas falladas guardadas en una práctica anterior, SIN tocar la
  /// caché de repaso: la tiene que rehacer la app al arrancar.
  Future<void> failedEarlier(List<String> questionIds) async {
    final progress = DriftProgressRepository(
      db,
      clock: () => now.subtract(const Duration(hours: 1)),
    );
    final session = await progress.startSession(
      packId: packId,
      mode: SessionMode.practice,
      config: {'questionIds': questionIds},
    );
    for (final id in questionIds) {
      await progress.recordAnswer(
        sessionId: session.id,
        questionId: id,
        chosen: 'a',
        isCorrect: false,
        timeMs: 1000,
      );
    }
  }

  Future<void> startApp(WidgetTester tester) async {
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
  }

  OutlinedButton reviewButton(WidgetTester tester) => tester.widget(
    find.ancestor(
      of: find.byIcon(Icons.replay),
      matching: find.byWidgetPredicate((w) => w is OutlinedButton),
    ),
  );

  testWidgets('sin fallos no hay nada que repasar', (tester) async {
    await startApp(tester);

    expect(find.text('Nada pendiente hoy'), findsOneWidget);
    expect(reviewButton(tester).onPressed, isNull);
  });

  testWidgets('el contador sale de los fallos guardados (reconstrucción al '
      'arrancar); repasar los baja y el resumen vuelve al repaso', (
    tester,
  ) async {
    await tester.runAsync(() => failedEarlier(['e1-01', 'e1-r1']));
    await startApp(tester);

    expect(find.text('Repasar (2)'), findsOneWidget);
    await tapAndSettle(tester, find.text('Repasar (2)'));

    expect(find.text('pendientes hoy'), findsOneWidget);
    expect(find.text('Dominadas (3 aciertos seguidos): 0'), findsOneWidget);
    await tapAndSettle(tester, find.text('Empezar repaso (2)'));

    // Mismo instante y caja: van en el orden del pack.
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    expect(
      find.text('¿En qué año se aprobó la Constitución española?'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('1978'));
    expect(find.text('¡Correcto!'), findsOneWidget);
    await tapAndSettle(tester, find.text('Siguiente'));

    expect(find.text('¿Qué puerto usa HTTPS por defecto?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Saltar (en blanco)'));
    await tapAndSettle(tester, find.text('Ver resumen'));

    expect(find.text('Resumen'), findsOneWidget);
    await tapAndSettle(tester, find.text('Volver al repaso'));

    // La acertada sube a la caja 1 (mañana); la de en blanco sigue en la 0.
    expect(find.text('pendiente hoy'), findsOneWidget);
    expect(find.text('Empezar repaso (1)'), findsOneWidget);

    final states = await tester.runAsync(
      () => db.select(db.reviewStates).get(),
    );
    expect(
      {for (final s in states!) s.questionId: s.box},
      {'e1-01': 1, 'e1-r1': 0},
    );
  });

  testWidgets('con todo repasado muestra el próximo repaso', (tester) async {
    await tester.runAsync(() => failedEarlier(['e1-01']));
    await startApp(tester);
    await tapAndSettle(tester, find.text('Repasar (1)'));
    await tapAndSettle(tester, find.text('Empezar repaso (1)'));
    await tapAndSettle(tester, find.text('1978'));
    await tapAndSettle(tester, find.text('Ver resumen'));
    await tapAndSettle(tester, find.text('Volver al repaso'));

    expect(find.text('pendientes hoy'), findsOneWidget);
    // Caja 1: toca mañana. La fecha exacta depende de la zona horaria de la
    // máquina de tests (se muestra en hora local), así que solo se comprueba
    // que aparece.
    expect(find.textContaining('Próximo repaso:'), findsOneWidget);
    expect(find.textContaining('Empezar repaso'), findsNothing);
  });
}
