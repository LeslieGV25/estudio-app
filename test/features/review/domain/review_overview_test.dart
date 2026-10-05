import 'package:estudio_app/features/review/domain/review_overview.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5, 10);
  final today = DateTime.utc(2026, 10, 4, 22);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));
  final nextWeek = today.add(const Duration(days: 7));

  ReviewState state(int box, DateTime nextDue, {int streak = 0}) =>
      ReviewState(box: box, correctStreak: streak, nextDue: nextDue);

  test('solo cuenta preguntas que se pueden estudiar', () {
    final overview = ReviewOverview.from(
      {
        'normal': state(0, today),
        'anulada': state(0, today),
        'obsoleta': state(0, today),
        'eliminada': state(0, today), // ya no está en el pack
      },
      [
        studyQuestion('normal'),
        studyQuestion('anulada', voided: true),
        studyQuestion('obsoleta', obsolete: true),
        studyQuestion('sin-estado'),
      ],
      now,
    );

    expect(overview.items.map((i) => i.question.id), ['normal']);
    expect(overview.dueIds(), ['normal']);
  });

  test('pendientes: las que tocan hasta ahora, no las futuras', () {
    final overview = ReviewOverview.from(
      {'hoy': state(0, today), 'mañana': state(1, tomorrow)},
      [studyQuestion('hoy'), studyQuestion('mañana')],
      now,
    );

    expect(overview.dueIds(), ['hoy']);
    expect(overview.items, hasLength(2));
  });

  test('orden: más atrasada, luego caja más baja, luego orden del pack', () {
    final overview = ReviewOverview.from(
      {
        'hoy-caja2': state(2, today),
        'hoy-caja0-b': state(0, today),
        'hoy-caja0-a': state(0, today),
        'ayer': state(3, yesterday),
      },
      [
        studyQuestion('hoy-caja2', position: 0),
        studyQuestion('hoy-caja0-b', position: 2),
        studyQuestion('hoy-caja0-a', position: 1),
        studyQuestion('ayer', position: 3),
      ],
      now,
    );

    expect(overview.dueIds(), [
      'ayer',
      'hoy-caja0-a',
      'hoy-caja0-b',
      'hoy-caja2',
    ]);
    expect(overview.dueIds(limit: 2), ['ayer', 'hoy-caja0-a']);
  });

  test('cuenta cajas y dominadas', () {
    final overview = ReviewOverview.from(
      {
        'a': state(0, today),
        'b': state(0, today),
        'c': state(3, nextWeek, streak: 3),
        'd': state(4, nextWeek, streak: 4),
      },
      [
        for (final id in ['a', 'b', 'c', 'd']) studyQuestion(id),
      ],
      now,
    );

    expect(overview.boxCounts, [2, 0, 0, 1, 1]);
    expect(overview.mastered, 2);
  });

  test('próximo repaso solo si hoy no queda nada', () {
    final questions = [studyQuestion('a'), studyQuestion('b')];

    final nothingToday = ReviewOverview.from(
      {'a': state(3, nextWeek), 'b': state(1, tomorrow)},
      questions,
      now,
    );
    expect(nothingToday.nextDue, tomorrow);

    final somethingToday = ReviewOverview.from(
      {'a': state(0, today), 'b': state(1, tomorrow)},
      questions,
      now,
    );
    expect(somethingToday.nextDue, isNull);

    expect(ReviewOverview.from({}, questions, now).nextDue, isNull);
  });
}
