import 'package:estudio_app/app.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const EstudioApp(),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  testWidgets('arranca en la pantalla de packs', (tester) async {
    await startApp(tester);

    expect(find.text('Mis packs'), findsOneWidget);
  });

  testWidgets('el botón de tema no lanza excepciones al cambiar de modo', (
    tester,
  ) async {
    await startApp(tester);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.brightness_6_outlined));
      await tester.pumpAndSettle();
    }
  });
}
