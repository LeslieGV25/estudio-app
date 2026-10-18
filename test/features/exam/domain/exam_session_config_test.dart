import 'dart:convert';

import 'package:estudio_app/features/exam/domain/exam_paper.dart';
import 'package:estudio_app/features/exam/domain/exam_session_config.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const paper = ExamPaper(
    exerciseId: 'ej1',
    name: 'Primer ejercicio',
    questionCount: 3,
    questionIds: ['q1', 'q2', 'q3'],
    voidedIds: ['q9'],
    replacements: {'q9': 'q3'},
    durationMin: 55,
    scoring: Scoring(
      mode: ScoringMode.proportional,
      maxScore: 10,
      wrongFactor: 0.25,
    ),
  );
  const config = ExamSessionConfig(setup: ExamSetup(), paper: paper);

  test('marcar, cambiar y dejar en blanco', () {
    final marked = config.withChoice('q1', 'a').withChoice('q2', 'b');
    final changed = marked.withChoice('q1', 'c');
    final cleared = changed.withChoice('q2', null);

    expect(marked.choices, {'q1': 'a', 'q2': 'b'});
    expect(changed.choices, {'q1': 'c', 'q2': 'b'});
    expect(cleared.choices, {'q1': 'c'});
    expect(cleared.answeredCount, 1);
    expect(cleared.blankCount, 2);
  });

  test('el tiempo de cada pregunta se acumula entre visitas', () {
    final updated = config
        .withTimeSpent('q1', 1000)
        .withTimeSpent('q2', 500)
        .withTimeSpent('q1', 250);

    expect(updated.timeMs, {'q1': 1250, 'q2': 500});
  });

  test('no se puede marcar una pregunta de otro ejercicio', () {
    expect(() => config.withChoice('otra', 'a'), throwsStateError);
    expect(() => config.withTimeSpent('otra', 1), throwsStateError);
  });

  test('hora límite = inicio + duración; sin duración no hay', () {
    final start = DateTime.utc(2026, 10, 18, 9);

    expect(config.deadline(start), DateTime.utc(2026, 10, 18, 9, 55));
    expect(
      config.copyWith(paper: paper.copyWith(durationMin: null)).deadline(start),
      isNull,
    );
  });

  test('se guarda y se lee como JSON sin perder nada', () {
    final full = config
        .withChoice('q1', 'a')
        .withTimeSpent('q1', 1200)
        .copyWith(
          pending: [paper.copyWith(exerciseId: 'ej2')],
          previousSessionId: 'antes',
          nextSessionId: 'despues',
          currentIndex: 2,
        );

    // Ida y vuelta por texto, como en la base de datos.
    final restored = ExamSessionConfig.fromJson(
      jsonDecode(jsonEncode(full.toJson())) as Map<String, dynamic>,
    );

    expect(restored, full);
  });
}
