import 'dart:io';
import 'dart:math';

import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/packs/data/pack_providers.dart';
import 'package:estudio_app/features/practice/presentation/practice_providers.dart';
import 'package:estudio_app/features/review/data/review_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/review.dart';
import '../../../helpers/test_database.dart';

/// Simulacro completo del examen real del pack `completo`:
/// - ej1 (55 min, proporcional): e1-01 Constitución (b = 1978) y la reserva
///   e1-r1 HTTPS (b = 443), que sustituye a la anulada e1-02.
/// - ej2 (sin tiempo, fijo +1 / −0,33): e2-01 el script (b = Comprime).
void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = cal.at(2026, 10, 18, 10);
  });
  tearDown(() => db.close());

  // Sin pumpAndSettle: el temporizador repinta cada segundo y nunca se
  // «asienta». Se deja avanzar un tiempo fijo (las animaciones de diálogos
  // y rutas duran menos) y la base de datos con runAsync.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(finder);
    await settle(tester);
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
          practiceRandomProvider.overrideWithValue(Random(1)),
        ],
        child: const EstudioApp(),
      ),
    );
    await settle(tester);
  }

  Future<void> openRealExam(WidgetTester tester) async {
    await startApp(tester);
    await tapAndSettle(tester, find.text('Simulacro'));
    await tapAndSettle(tester, find.text('Examen real'));
  }

  Future<void> submit(WidgetTester tester) async {
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Entregar'));
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entregar'));
  }

  testWidgets('la configuración anuncia lo que tendrá cada ejercicio', (
    tester,
  ) async {
    await openRealExam(tester);

    expect(find.text('Examen 2026'), findsOneWidget);
    expect(find.text('2 preguntas · 55 min'), findsOneWidget);
    expect(find.text('Anuladas sustituidas por reserva: 1'), findsOneWidget);
    expect(find.text('1 pregunta · sin límite de tiempo'), findsOneWidget);
  });

  testWidgets('simulacro completo: sin feedback hasta el final y con nota', (
    tester,
  ) async {
    await openRealExam(tester);
    await tapAndSettle(tester, find.text('Empezar simulacro'));

    // Ej. 1: temporizador, sin corrección al marcar.
    expect(find.text('Primer ejercicio'), findsOneWidget);
    expect(find.text('55:00'), findsOneWidget);
    expect(find.text('Pregunta 1 de 2'), findsOneWidget);
    await tapAndSettle(tester, find.text('1978'));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.cancel), findsNothing);

    // La reserva queda en blanco.
    await tapAndSettle(tester, find.byTooltip('Siguiente'));
    expect(find.text('¿Qué puerto usa HTTPS por defecto?'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Entregar'));
    expect(find.textContaining('Quedan 1 en blanco'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Entregar'));

    // Entre ejercicios no se ve la nota.
    expect(find.text('Primer ejercicio: entregado'), findsOneWidget);
    expect(find.textContaining('5,000'), findsNothing);
    now = now.add(const Duration(minutes: 3));
    await tapAndSettle(tester, find.text('Empezar el siguiente ejercicio'));

    // Ej. 2: sin tiempo.
    expect(find.text('Segundo ejercicio'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    await tapAndSettle(tester, find.text('Borra los .log'));
    await submit(tester);
    await tapAndSettle(tester, find.text('Ver resultado'));

    // Ej. 1: 2 valorables, 1 acierto + 1 en blanco = 5,000 (apto).
    // Ej. 2: un fallo = −0,33 (no apto).
    expect(find.text('Resultado del simulacro'), findsOneWidget);
    expect(find.text('5,000'), findsOneWidget);
    expect(find.text('−0,33'), findsOneWidget);
    expect(find.text('APTO'), findsOneWidget);
    expect(find.text('NO APTO'), findsOneWidget);
    expect(
      find.text('Te faltaban 0,83 aciertos netos para el 0,50'),
      findsOneWidget,
    );
    expect(find.text('Repasar estas (2)'), findsOneWidget);

    final answers = await tester.runAsync(() => db.select(db.answers).get());
    expect(
      {for (final a in answers!) a.questionId: a.chosen},
      {'e1-01': 'b', 'e1-r1': null, 'e2-01': 'a'},
    );
  });

  testWidgets('si no se aprueba el ej. 1, el ej. 2 sale «no corregido»', (
    tester,
  ) async {
    await openRealExam(tester);
    await tapAndSettle(tester, find.text('Empezar simulacro'));
    await tapAndSettle(tester, find.text('1976'));
    await submit(tester);
    await tapAndSettle(tester, find.text('Empezar el siguiente ejercicio'));
    await tapAndSettle(tester, find.text('Comprime cada .log'));
    await submit(tester);
    await tapAndSettle(tester, find.text('Ver resultado'));

    expect(
      find.text('No corregido: no se superó el ejercicio anterior'),
      findsOneWidget,
    );
    // Solo hay una nota y un veredicto: los del ej. 1.
    expect(find.text('NO APTO'), findsOneWidget);
    expect(find.text('APTO'), findsNothing);
    expect(find.text('Ver tus respuestas'), findsOneWidget);
  });

  testWidgets('al acabarse el tiempo se entrega solo', (tester) async {
    await openRealExam(tester);
    await tapAndSettle(tester, find.text('Empezar simulacro'));
    await tapAndSettle(tester, find.text('1978'));

    now = now.add(const Duration(minutes: 55));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.text('Primer ejercicio: entregado'), findsOneWidget);
    final answers = await tester.runAsync(() => db.select(db.answers).get());
    expect(answers!.map((a) => a.chosen), ['b', null]);
  });
}
