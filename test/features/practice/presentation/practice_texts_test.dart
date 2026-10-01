import 'dart:math';

import 'package:estudio_app/features/practice/domain/practice_filter.dart';
import 'package:estudio_app/features/practice/domain/practice_plan.dart';
import 'package:estudio_app/features/practice/presentation/practice_setup_controller.dart';
import 'package:estudio_app/features/practice/presentation/question_labels.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  group('practicePlanNotice', () {
    // Un supuesto de 3 y 2 sueltas; se piden 4.
    final questions = [
      for (var i = 0; i < 3; i++)
        studyQuestion('x$i', position: i, contextId: 'x'),
      studyQuestion('s1', position: 3),
      studyQuestion('s2', position: 4),
    ];
    final plans = [
      for (var seed = 0; seed < 50; seed++)
        PracticePlan.build(
          questions,
          const PracticeFilter(questionCount: 4),
          random: Random(seed),
        ),
    ];

    test('avisa con el nº real cuando un supuesto no cabía', () {
      final shortened = plans.firstWhere((p) => p.count < 4);

      expect(
        practicePlanNotice(shortened),
        'Se usarán ${shortened.count}: un supuesto no cabía entero',
      );
    });

    test('sin aviso cuando sale el nº pedido', () {
      expect(practicePlanNotice(plans.firstWhere((p) => p.count == 4)), isNull);
    });
  });

  group('etiquetas de pregunta', () {
    test('origen con número de pregunta', () {
      final q = studyQuestion('q');
      final numbered = q.copyWith(question: q.question.copyWith(number: '7'));

      expect(questionOrigin(numbered), 'Fuente examen · Pregunta 7');
    });

    test('origen sin número: solo la fuente', () {
      expect(questionOrigin(studyQuestion('q')), 'Fuente examen');
    });

    test('tema y opción', () {
      final q = studyQuestion('q', topicId: 35);

      expect(questionTopic(q), 'Tema 35 · Tema 35');
      expect(optionLabel(q.question, 'b'), 'b) Opción B');
    });
  });
}
