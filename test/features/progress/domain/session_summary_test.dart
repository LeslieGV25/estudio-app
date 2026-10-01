import 'package:estudio_app/features/progress/domain/entities/answer.dart';
import 'package:estudio_app/features/progress/domain/session_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  var counter = 0;
  Answer answer(String questionId, String? chosen, {required bool correct}) =>
      Answer(
        id: 'ans-${counter++}',
        sessionId: 's',
        packId: 'p',
        questionId: questionId,
        chosen: chosen,
        isCorrect: correct,
        timeMs: 1000,
        answeredAt: DateTime.utc(2026, 10, 1),
      );

  final q1 = studyQuestion('q1', topicId: 1);
  final q2 = studyQuestion('q2', topicId: 1);
  final q3 = studyQuestion('q3', topicId: 2);
  final q4 = studyQuestion('q4', topicId: 2);
  final anulada = studyQuestion(
    'anulada',
    topicId: 2,
    voided: true,
    provisionalKey: 'a',
  );
  final sinResponder = studyQuestion('q5', topicId: 3);

  final summary = SessionSummary.from(
    [q1, q2, anulada, q3, q4, sinResponder],
    [
      answer('q1', 'a', correct: true),
      answer('q2', 'b', correct: false),
      answer('anulada', 'a', correct: true),
      answer('q3', 'a', correct: true),
      answer('q4', null, correct: false),
    ],
  );

  test('cuenta aciertos, fallos, en blanco, anuladas y sin responder', () {
    expect(summary.correct, 2);
    expect(summary.wrong, 1);
    expect(summary.blank, 1);
    expect(summary.notCounted, 1);
    expect(summary.unanswered, 1);
    expect(summary.counted, 4);
  });

  test('los porcentajes no incluyen anuladas ni sin responder', () {
    expect(summary.correctPercent, 50);
    expect(summary.wrongPercent, 25);
    expect(summary.blankPercent, 25);
  });

  test('cada pregunta conserva su orden y su resultado', () {
    expect(summary.items.map((i) => (i.question.id, i.outcome)), [
      ('q1', AnswerOutcome.correct),
      ('q2', AnswerOutcome.wrong),
      ('anulada', AnswerOutcome.notCounted),
      ('q3', AnswerOutcome.correct),
      ('q4', AnswerOutcome.blank),
      ('q5', AnswerOutcome.unanswered),
    ]);
  });

  test('una anulada acertada sigue sin contar', () {
    final item = summary.items.singleWhere((i) => i.question.id == 'anulada');

    expect(item.answer!.isCorrect, isTrue);
    expect(item.outcome, AnswerOutcome.notCounted);
    expect(summary.voided.map((i) => i.question.id), ['anulada']);
  });

  test('desglose por tema sin anuladas y sin temas vacíos', () {
    expect(
      summary.byTopic.map(
        (t) => (t.topicId, t.topicTitle, t.correct, t.wrong, t.blank),
      ),
      [(1, 'Tema 1', 1, 1, 0), (2, 'Tema 2', 1, 0, 1)],
    );
  });

  test('«repasar estas» = falladas y en blanco, sin anuladas', () {
    expect(summary.missed.map((i) => i.question.id), ['q2', 'q4']);
  });

  test('si una pregunta tiene dos respuestas cuenta la primera', () {
    final s = SessionSummary.from(
      [q1],
      [answer('q1', 'b', correct: false), answer('q1', 'a', correct: true)],
    );

    expect(s.wrong, 1);
    expect(s.correct, 0);
  });

  test('ignora respuestas a preguntas que ya no están', () {
    final s = SessionSummary.from(
      [q1],
      [answer('borrada', 'a', correct: true)],
    );

    expect(s.correct, 0);
    expect(s.unanswered, 1);
  });

  test('sin respuestas que cuenten, los porcentajes son 0', () {
    final s = SessionSummary.from(
      [anulada],
      [answer('anulada', 'a', correct: true)],
    );

    expect(s.counted, 0);
    expect(s.correctPercent, 0);
    expect(s.byTopic, isEmpty);
  });
}
