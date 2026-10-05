import 'package:estudio_app/features/progress/domain/entities/answer.dart';
import 'package:estudio_app/features/review/domain/leitner.dart';
import 'package:estudio_app/features/review/domain/review_calendar.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/review.dart';

void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  ReviewState? replay(List<Answer> answers) => Leitner.replay(answers, cal);

  // 5 de octubre de 2026, 10:00 en Madrid.
  final day1 = cal.at(2026, 10, 5, 10);
  DateTime dayN(int n, [int hour = 10]) => cal.at(2026, 10, 4 + n, hour);

  group('entrada en el repaso', () {
    test('sin respuestas no hay estado', () {
      expect(replay([]), isNull);
    });

    test('acertar sin haber fallado nunca no la mete en el repaso', () {
      expect(replay([reviewAnswer(day1), reviewAnswer(dayN(2))]), isNull);
    });

    test('un fallo la mete en la caja 0, pendiente desde hoy', () {
      final state = replay([reviewAnswer(day1, correct: false)]);

      expect(
        state,
        ReviewState(box: 0, correctStreak: 0, nextDue: cal.at(2026, 10, 5)),
      );
      expect(state!.isDue(day1), isTrue);
    });

    test('en blanco cuenta como fallo', () {
      expect(
        replay([reviewAnswer(day1, blank: true)]),
        replay([reviewAnswer(day1, correct: false)]),
      );
    });
  });

  group('subir de caja', () {
    test('cada acierto cuando toca sube una caja con su intervalo', () {
      final answers = [
        reviewAnswer(dayN(1), correct: false), // caja 0, toca el día 1
        reviewAnswer(dayN(1, 18)), // caja 1, +1 → día 2
        reviewAnswer(dayN(2)), // caja 2, +3 → día 5
        reviewAnswer(dayN(5)), // caja 3, +7 → día 12
        reviewAnswer(dayN(12)), // caja 4, +14 → día 26
      ];
      final expected = [
        (0, dayN(1, 0)),
        (1, dayN(2, 0)),
        (2, dayN(5, 0)),
        (3, dayN(12, 0)),
        (4, dayN(26, 0)),
      ];

      for (var i = 0; i < answers.length; i++) {
        final state = replay(answers.sublist(0, i + 1))!;
        expect((state.box, state.nextDue), expected[i], reason: 'paso $i');
      }
    });

    test('la caja 4 es el tope: otro acierto la deja en 4 a 14 días', () {
      final state = replay([
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 18)),
        reviewAnswer(dayN(2)),
        reviewAnswer(dayN(5)),
        reviewAnswer(dayN(12)),
        reviewAnswer(dayN(26)),
      ])!;

      expect(state.box, 4);
      expect(state.correctStreak, 5);
      expect(state.nextDue, dayN(40, 0));
    });

    test('un acierto antes de tiempo no cambia nada', () {
      final before = replay([
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 12)),
      ]);

      final after = replay([
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 12)),
        reviewAnswer(dayN(1, 13)), // mismo día: le tocaba el día 2
        reviewAnswer(dayN(1, 20)),
      ]);

      expect(after, before);
    });

    test('un fallo desde la caja 4 la devuelve a la caja 0', () {
      final state = replay([
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 18)),
        reviewAnswer(dayN(2)),
        reviewAnswer(dayN(5)),
        reviewAnswer(dayN(12)),
        reviewAnswer(dayN(13), correct: false),
      ])!;

      expect(state.box, 0);
      expect(state.correctStreak, 0);
      expect(state.nextDue, dayN(13, 0));
    });
  });

  group('dominada', () {
    test('con 3 aciertos seguidos que tocaban', () {
      final twoHits = [
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 18)),
        reviewAnswer(dayN(2)),
      ];
      expect(replay(twoHits)!.isMastered, isFalse);
      expect(replay([...twoHits, reviewAnswer(dayN(5))])!.isMastered, isTrue);
    });

    test('los aciertos antes de tiempo no cuentan para la racha', () {
      final state = replay([
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 11)),
        reviewAnswer(dayN(1, 12)),
        reviewAnswer(dayN(1, 13)),
      ])!;

      expect(state.correctStreak, 1);
      expect(state.isMastered, isFalse);
    });

    test('sigue en el repaso y la pierde al fallar', () {
      final mastered = [
        reviewAnswer(dayN(1), correct: false),
        reviewAnswer(dayN(1, 18)),
        reviewAnswer(dayN(2)),
        reviewAnswer(dayN(5)),
      ];
      expect(replay(mastered)!.nextDue, dayN(12, 0));

      expect(
        replay([...mastered, reviewAnswer(dayN(12), correct: false)])!
            .isMastered,
        isFalse,
      );
    });
  });

  group('días de calendario locales', () {
    test('fallar a las 23:59 y acertar a las 00:01 sube de caja', () {
      final state = replay([
        reviewAnswer(cal.at(2026, 10, 5, 23, 59), correct: false),
        reviewAnswer(cal.at(2026, 10, 5, 23, 59)), // caja 1: toca el 6
        reviewAnswer(cal.at(2026, 10, 6, 0, 1)), // solo 2 min después
      ])!;

      expect(state.box, 2);
      expect(state.nextDue, cal.at(2026, 10, 9));
    });

    test('el día lo marca la hora local, no la UTC', () {
      // 00:30 en Madrid es todavía el día anterior en UTC.
      final state = replay([
        reviewAnswer(cal.at(2026, 10, 6, 0, 30), correct: false),
      ])!;

      expect(state.nextDue, cal.at(2026, 10, 6));
      expect(state.nextDue, DateTime.utc(2026, 10, 5, 22));
    });

    test('los intervalos cruzan el fin de mes', () {
      final state = replay([
        reviewAnswer(cal.at(2026, 10, 30), correct: false),
        reviewAnswer(cal.at(2026, 10, 30, 12)), // caja 1 → 31
        reviewAnswer(cal.at(2026, 10, 31, 12)), // caja 2 → +3 = 3 nov
      ])!;

      expect(state.nextDue, cal.at(2026, 11, 3));
    });
  });

  test('ejemplo: fallo → acierto al día siguiente → acierto antes de tiempo '
      '→ fallo', () {
    final states = <ReviewState?>[];
    ReviewState? state;
    for (final answer in [
      reviewAnswer(dayN(1), correct: false),
      reviewAnswer(dayN(2)),
      reviewAnswer(dayN(2, 20)),
      reviewAnswer(dayN(3), correct: false),
    ]) {
      state = Leitner.apply(state, answer, cal);
      states.add(state);
    }

    expect(states, [
      ReviewState(box: 0, correctStreak: 0, nextDue: dayN(1, 0)),
      ReviewState(box: 1, correctStreak: 1, nextDue: dayN(3, 0)),
      ReviewState(box: 1, correctStreak: 1, nextDue: dayN(3, 0)),
      ReviewState(box: 0, correctStreak: 0, nextDue: dayN(3, 0)),
    ]);
  });

  group('LocalReviewCalendar', () {
    const local = LocalReviewCalendar();

    test('devuelve la medianoche local en UTC', () {
      final start = local.startOfDay(DateTime.utc(2026, 10, 5, 12));

      expect(start.isUtc, isTrue);
      final asLocal = start.toLocal();
      expect((asLocal.hour, asLocal.minute), (0, 0));
    });

    test('suma días de calendario cruzando el fin de mes', () {
      final start = local.startOfDay(
        DateTime(2026, 10, 31, 12).toUtc(),
        plusDays: 1,
      );

      final asLocal = start.toLocal();
      expect((asLocal.month, asLocal.day, asLocal.hour), (11, 1, 0));
    });
  });
}
