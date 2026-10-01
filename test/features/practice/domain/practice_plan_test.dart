import 'dart:math';

import 'package:estudio_app/features/practice/domain/practice_filter.dart';
import 'package:estudio_app/features/practice/domain/practice_plan.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  /// Un supuesto de 3 (x1–x3), 2 sueltas y una anulada.
  final questions = [
    studyQuestion('x1', position: 0, contextId: 'x'),
    studyQuestion('x2', position: 1, contextId: 'x'),
    studyQuestion('x3', position: 2, contextId: 'x'),
    studyQuestion('s1', position: 3),
    studyQuestion('s2', position: 4),
    studyQuestion('anulada', position: 5, voided: true, provisionalKey: 'a'),
  ];

  PracticePlan plan(PracticeFilter filter, {int seed = 1}) =>
      PracticePlan.build(questions, filter, random: Random(seed));

  test('cuenta las disponibles con el filtro, sin anuladas', () {
    final p = plan(const PracticeFilter());

    expect(p.available, 5);
    expect(p.count, 5);
    expect(p.questionIds, isNot(contains('anulada')));
    expect(p.isShortenedByCaseStudy, isFalse);
  });

  test('guarda el filtro con el que se calculó', () {
    const filter = PracticeFilter(questionCount: 2);

    expect(plan(filter).filter, filter);
  });

  test('avisa si un supuesto que no cabe deja la sesión más corta', () {
    // Se piden 4 de 5. Si el supuesto (3) sale el último del barajado, ya
    // están las 2 sueltas y no cabe entero: la sesión se queda en 2. En los
    // demás órdenes salen 4 (supuesto + una suelta).
    final shortened = [
      for (var seed = 0; seed < 50; seed++)
        plan(const PracticeFilter(questionCount: 4), seed: seed),
    ].where((p) => p.count < 4);

    expect(shortened, isNotEmpty, reason: 'alguna semilla debe acortar');
    for (final p in shortened) {
      expect(p.isShortenedByCaseStudy, isTrue);
      expect(p.available, 5);
    }
  });

  test('sin aviso si se piden más de las que hay', () {
    final p = plan(const PracticeFilter(questionCount: 20));

    expect(p.count, 5);
    expect(p.isShortenedByCaseStudy, isFalse);
  });

  test('sin aviso si no se limita el nº de preguntas', () {
    expect(plan(const PracticeFilter()).isShortenedByCaseStudy, isFalse);
  });

  test('vacío si nada cumple el filtro', () {
    final p = plan(const PracticeFilter(sourceIds: {'otra'}));

    expect(p.isEmpty, isTrue);
    expect(p.available, 0);
  });
}
