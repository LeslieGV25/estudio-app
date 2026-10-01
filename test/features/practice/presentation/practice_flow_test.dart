import 'dart:io';
import 'dart:math';

import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/packs/data/pack_providers.dart';
import 'package:estudio_app/features/practice/presentation/practice_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

/// Flujo completo de práctica sobre el pack `completo` (instalado como pack
/// incluido): Constitución (e1-01, con explicación; e1-03 obsoleta), Redes
/// (e1-02 anulada; e1-r1 sin explicación) y Linux (e2-01 con supuesto;
/// est-01 de estudio).
void main() {
  late AppDatabase db;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = DateTime.utc(2026, 10, 1, 9);
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

  /// Arranca la app y abre la configuración de práctica.
  Future<void> openSetup(WidgetTester tester) async {
    // Pantalla alta para que la configuración quepa sin hacer scroll.
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
          practiceRandomProvider.overrideWithValue(Random(1)),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const EstudioApp(),
      ),
    );
    await settle(tester);
    await tapAndSettle(tester, find.text('Practicar'));
  }

  /// Marca un tema dentro de su bloque (desplegándolo antes).
  Future<void> chooseTopic(
    WidgetTester tester,
    String block,
    String topic,
  ) async {
    await tapAndSettle(tester, find.text(block));
    await tapAndSettle(tester, find.text(topic));
  }

  testWidgets('el recuento cambia en vivo con los filtros', (tester) async {
    await openSetup(tester);

    // Sin anulada (e1-02) ni obsoleta (e1-03).
    expect(find.text('4 preguntas disponibles'), findsOneWidget);
    expect(find.text('Empezar (4)'), findsOneWidget);

    await tapAndSettle(tester, find.text('Solo preguntas oficiales'));
    expect(find.text('3 preguntas disponibles'), findsOneWidget);

    await tapAndSettle(tester, find.text('Incluir obsoletas'));
    expect(find.text('4 preguntas disponibles'), findsOneWidget);

    await tapAndSettle(tester, find.text('Preguntas de estudio'));
    expect(find.text('Ninguna pregunta cumple estos filtros.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('fallar: feedback con la correcta y la explicación; resumen y '
      '«repasar estas»', (tester) async {
    await openSetup(tester);
    await chooseTopic(tester, 'Bloque común', 'Tema 1. Constitución');
    expect(find.text('1 pregunta disponible'), findsOneWidget);

    await tapAndSettle(tester, find.text('Empezar (1)'));

    expect(find.text('Pregunta 1 de 1'), findsOneWidget);
    expect(find.text('Examen 2026 · Pregunta 1'), findsOneWidget);
    expect(find.text('Tema 1 · Constitución'), findsOneWidget);

    now = now.add(const Duration(seconds: 12));
    await tapAndSettle(tester, find.text('1976'));

    expect(find.text('Incorrecto'), findsOneWidget);
    expect(find.text('Respuesta correcta: b) 1978'), findsOneWidget);
    expect(find.text('Explicación'), findsOneWidget);
    expect(find.text('Referéndum del 6 de diciembre de 1978.'), findsOneWidget);

    final answer = await tester.runAsync(
      () => db.select(db.answers).getSingle(),
    );
    expect(answer!.chosen, 'a');
    expect(answer.isCorrect, isFalse);
    expect(answer.timeMs, 12000);

    await tapAndSettle(tester, find.text('Ver resumen'));

    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('0 %'), findsWidgets);
    expect(find.text('Falladas y en blanco (1)'), findsOneWidget);

    await tapAndSettle(tester, find.text('Repasar estas (1)'));

    expect(find.text('Pregunta 1 de 1'), findsOneWidget);
    expect(
      find.text('¿En qué año se aprobó la Constitución española?'),
      findsOneWidget,
    );
    await tapAndSettle(tester, find.text('1978'));
    expect(find.text('¡Correcto!'), findsOneWidget);
  });

  testWidgets('acertar una pregunta sin explicación no deja hueco', (
    tester,
  ) async {
    await openSetup(tester);
    await chooseTopic(tester, 'Bloque técnico', 'Tema 2. Redes');
    await tapAndSettle(tester, find.text('Empezar (1)'));

    await tapAndSettle(tester, find.text('443'));

    expect(find.text('¡Correcto!'), findsOneWidget);
    expect(find.textContaining('Respuesta correcta'), findsNothing);
    expect(find.text('Explicación'), findsNothing);
  });

  testWidgets('«Saltar» guarda en blanco y muestra la correcta', (
    tester,
  ) async {
    await openSetup(tester);
    await chooseTopic(tester, 'Bloque técnico', 'Tema 2. Redes');
    await tapAndSettle(tester, find.text('Empezar (1)'));

    await tapAndSettle(tester, find.text('Saltar (en blanco)'));

    expect(find.text('En blanco'), findsOneWidget);
    expect(find.text('Respuesta correcta: b) 443'), findsOneWidget);
    final answer = await tester.runAsync(
      () => db.select(db.answers).getSingle(),
    );
    expect(answer!.chosen, isNull);
  });

  testWidgets('el supuesto se muestra encima con el código monoespaciado', (
    tester,
  ) async {
    await openSetup(tester);
    await chooseTopic(tester, 'Bloque técnico', 'Tema 3. Linux');
    await tapAndSettle(tester, find.text('Examen 2026'));
    await tapAndSettle(tester, find.text('Empezar (1)'));

    expect(find.text('Supuesto 1'), findsOneWidget);
    expect(find.text('Administras un servidor Linux.'), findsOneWidget);
    final code = tester.widget<SelectableText>(
      find.byWidgetPredicate(
        (w) => w is SelectableText && (w.data ?? '').contains('gzip'),
      ),
    );
    expect(code.style?.fontFamily, 'monospace');

    // El contexto va antes que el enunciado.
    final contextY = tester.getTopLeft(find.text('Supuesto 1')).dy;
    final statementY = tester.getTopLeft(find.text('¿Qué hace el script?')).dy;
    expect(contextY, lessThan(statementY));
  });

  testWidgets('«Terminar» a mitad deja las demás sin responder', (
    tester,
  ) async {
    await openSetup(tester);
    await chooseTopic(tester, 'Bloque técnico', 'Tema 3. Linux');
    await tapAndSettle(tester, find.text('Empezar (2)'));

    await tapAndSettle(tester, find.text('Terminar'));

    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('Sin responder: 2'), findsOneWidget);
    expect(find.textContaining('Repasar estas'), findsNothing);
  });
}
