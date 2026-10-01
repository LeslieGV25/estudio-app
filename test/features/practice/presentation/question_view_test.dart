import 'package:estudio_app/features/packs/domain/entities/study_question.dart';
import 'package:estudio_app/features/practice/presentation/widgets/question_view.dart';
import 'package:estudio_app/features/progress/domain/entities/answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester,
    StudyQuestion question, {
    Answer? answer,
    ValueChanged<String>? onChoose,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuestionView(
            question: question,
            answer: answer,
            onChoose: onChoose ?? (_) {},
          ),
        ),
      ),
    ),
  );

  const sql = 'SELECT id\nFROM empleados\nWHERE activo = \'S\';';
  final withSql = () {
    final q = studyQuestion('q');
    return q.copyWith(
      question: q.question.copyWith(
        options: const {'a': sql, 'b': 'Ninguna'},
        number: '7',
      ),
    );
  }();

  testWidgets('una opción multilínea se ve monoespaciada y con sus líneas', (
    tester,
  ) async {
    await pumpView(tester, withSql);

    final option = tester.widget<Text>(find.text(sql));
    expect(option.style?.fontFamily, 'monospace');
    expect(option.softWrap, isFalse);
    // Una opción de una línea se queda con el texto normal.
    expect(tester.widget<Text>(find.text('Ninguna')).style?.fontFamily, isNull);
  });

  testWidgets('la opción multilínea se puede elegir tocándola', (tester) async {
    String? chosen;
    await pumpView(tester, withSql, onChoose: (key) => chosen = key);

    await tester.tap(find.text(sql));

    expect(chosen, 'a');
  });

  testWidgets('muestra fuente con número y tema', (tester) async {
    await pumpView(tester, withSql);

    expect(find.text('Fuente examen · Pregunta 7'), findsOneWidget);
    expect(find.text('Tema 1 · Tema 1'), findsOneWidget);
  });

  testWidgets('ya respondida: marca correcta y elegida y no deja tocar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? chosen;
    await pumpView(
      tester,
      studyQuestion('q', correctKey: 'b'),
      answer: Answer(
        id: 'x',
        sessionId: 's',
        packId: 'p',
        questionId: 'q',
        chosen: 'a',
        isCorrect: false,
        timeMs: 1,
        answeredAt: DateTime.utc(2026),
      ),
      onChoose: (key) => chosen = key,
    );

    // El InkWell fusiona la semántica de la opción: «b) Opción B Respuesta
    // correcta»; un lector de pantalla lo dice todo junto.
    expect(
      find.bySemanticsLabel(RegExp(r'Opción B\s+Respuesta correcta')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Opción A\s+Tu respuesta, incorrecta')),
      findsOneWidget,
    );
    await tester.tap(find.text('Opción C'));
    expect(chosen, isNull);
    semantics.dispose();
  });
}
