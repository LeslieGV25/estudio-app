import 'dart:async';
import 'dart:io';

import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/features/packs/data/pack_file_picker.dart';
import 'package:estudio_app/features/packs/data/pack_providers.dart';
import 'package:estudio_app/features/packs/presentation/packs_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

/// Selector de ficheros falso: devuelve lo que el test ponga en [next].
class FakePackFilePicker implements PackFilePicker {
  List<int>? next;

  @override
  Future<List<int>?> pickPackFile() async => next;
}

const zgzName = 'Técnico/a Auxiliar Informática · Ayto. Zaragoza';

void main() {
  late AppDatabase db;
  late FakePackFilePicker picker;

  setUp(() {
    db = newTestDatabase();
    picker = FakePackFilePicker();
  });
  tearDown(() => db.close());

  /// Arranca la app con la base de datos en memoria y el asset real del
  /// pack de Zaragoza (el declarado en pubspec.yaml).
  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          packFilePickerProvider.overrideWithValue(picker),
        ],
        child: const EstudioApp(),
      ),
    );
  }

  /// Espera a que termine el trabajo de base de datos y asset, que corre
  /// fuera del reloj falso de los tests de widgets.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> importFile(WidgetTester tester, String path) async {
    picker.next = File(path).readAsBytesSync();
    await tester.tap(find.text('Importar'));
    await settle(tester);
  }

  testWidgets('primer arranque: indicador de carga y después el pack incluido '
      'ya activo', (tester) async {
    // El asset se "carga" solo cuando el test lo decide, para poder ver la
    // pantalla mientras se importa.
    final assetLoaded = Completer<List<int>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bundledPackLoaderProvider.overrideWithValue(() => assetLoaded.future),
        ],
        child: const EstudioApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Preparando el pack incluido…'), findsOneWidget);

    assetLoaded.complete(File(zaragozaPath).readAsBytesSync());
    await settle(tester);

    expect(find.text(zgzName), findsOneWidget);
    expect(find.text('v1.1.0 · 371 preguntas · Activo'), findsOneWidget);
  });

  testWidgets('borrar el único pack muestra el aviso acordado y deja el '
      'estado vacío con el botón de importar', (tester) async {
    await startApp(tester);
    await settle(tester);

    await tester.tap(find.byTooltip('Borrar pack'));
    await tester.pumpAndSettle();
    expect(find.text('¿Borrar «$zgzName»?'), findsOneWidget);
    expect(find.text(deletePackMessage), findsOneWidget);

    await tester.tap(find.text('Borrar'));
    await settle(tester);

    expect(find.text('Aún no tienes ningún pack'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Importar pack'), findsOneWidget);
  });

  testWidgets('cancelar el borrado no borra nada', (tester) async {
    await startApp(tester);
    await settle(tester);

    await tester.tap(find.byTooltip('Borrar pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await settle(tester);

    expect(find.text(zgzName), findsOneWidget);
  });

  testWidgets('importar desde el estado vacío instala y activa el pack', (
    tester,
  ) async {
    await startApp(tester);
    await settle(tester);
    await tester.tap(find.byTooltip('Borrar pack'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await settle(tester);

    picker.next = File(ejemploMinimoPath).readAsBytesSync();
    await tester.tap(find.text('Importar pack'));
    await settle(tester);

    expect(find.text('Pack «Pack de ejemplo» instalado'), findsOneWidget);
    expect(find.text('v1.0.0 · 2 preguntas · Activo'), findsOneWidget);
  });

  testWidgets('importar un segundo pack no cambia el activo; tocarlo sí', (
    tester,
  ) async {
    await startApp(tester);
    await settle(tester);

    await importFile(tester, ejemploMinimoPath);
    expect(find.text('v1.0.0 · 2 preguntas'), findsOneWidget);
    expect(find.text('v1.1.0 · 371 preguntas · Activo'), findsOneWidget);

    await tester.tap(find.text('Pack de ejemplo'));
    await settle(tester);
    expect(find.text('v1.0.0 · 2 preguntas · Activo'), findsOneWidget);
    expect(find.text('v1.1.0 · 371 preguntas'), findsOneWidget);
  });

  testWidgets('borrar el pack activo activa el otro', (tester) async {
    await startApp(tester);
    await settle(tester);
    await importFile(tester, ejemploMinimoPath);

    // El de Zaragoza (activo) es el segundo por orden alfabético.
    await tester.tap(find.byTooltip('Borrar pack').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await settle(tester);

    expect(find.text(zgzName), findsNothing);
    expect(find.text('v1.0.0 · 2 preguntas · Activo'), findsOneWidget);
  });

  testWidgets('un fichero inválido muestra los errores del validador', (
    tester,
  ) async {
    await startApp(tester);
    await settle(tester);

    await importFile(
      tester,
      'test/fixtures/packs/invalid/pregunta-duplicada.pack.json',
    );

    expect(find.text('El fichero no es un pack válido'), findsOneWidget);
    expect(find.text('• pregunta duplicada: e1-01'), findsOneWidget);
  });

  testWidgets('la misma versión pide confirmación antes de reemplazar', (
    tester,
  ) async {
    await startApp(tester);
    await settle(tester);

    await importFile(tester, zaragozaPath);

    expect(find.text('Ya tienes este pack'), findsOneWidget);
    expect(find.textContaining('la misma versión'), findsOneWidget);

    await tester.tap(find.text('Reemplazar'));
    await settle(tester);

    expect(find.text('Pack «$zgzName» reemplazado'), findsOneWidget);
  });

  testWidgets('cancelar el selector de ficheros no hace nada', (tester) async {
    await startApp(tester);
    await settle(tester);

    picker.next = null;
    await tester.tap(find.text('Importar'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
