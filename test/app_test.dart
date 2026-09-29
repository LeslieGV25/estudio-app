import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:estudio_app/app.dart';

void main() {
  testWidgets('arranca en la pantalla de inicio', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EstudioApp()));
    await tester.pumpAndSettle();

    expect(find.text('Estudio por packs'), findsWidgets);
  });

  testWidgets('el botón de tema no lanza excepciones al cambiar de modo', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EstudioApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.brightness_6_outlined));
    await tester.pumpAndSettle();
  });
}
