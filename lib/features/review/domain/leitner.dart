import 'dart:math';

import '../../progress/domain/entities/answer.dart';
import 'review_calendar.dart';
import 'review_state.dart';

/// Reglas de Leitner del repaso de fallos.
///
/// - Una pregunta entra al fallarla o dejarla en blanco (caja 0).
/// - Fallo o blanco → caja 0 y racha a 0, siempre.
/// - Acierto → sube una caja (máx. 4) y suma uno a la racha, **solo si ya
///   tocaba**. Un acierto antes de tiempo no cambia nada: así no se llega a
///   «dominada» repitiendo la misma pregunta en una tarde.
abstract final class Leitner {
  /// Días hasta el siguiente repaso según la caja (índice = caja).
  static const intervalDays = [0, 1, 3, 7, 14];

  static int get maxBox => intervalDays.length - 1;

  /// Estado tras [answers] (de una misma pregunta, en orden cronológico);
  /// `null` si la pregunta no ha entrado en el repaso.
  static ReviewState? replay(
    Iterable<Answer> answers,
    ReviewCalendar calendar,
  ) {
    ReviewState? state;
    for (final answer in answers) {
      state = apply(state, answer, calendar);
    }
    return state;
  }

  /// Un paso de [replay]: el estado después de [answer].
  static ReviewState? apply(
    ReviewState? state,
    Answer answer,
    ReviewCalendar calendar,
  ) {
    if (!answer.isCorrect) {
      // En blanco también llega aquí: `isCorrect` es false.
      return ReviewState(
        box: 0,
        correctStreak: 0,
        nextDue: calendar.startOfDay(answer.answeredAt),
      );
    }
    if (state == null || !state.isDue(answer.answeredAt)) return state;

    final box = min(state.box + 1, maxBox);
    return ReviewState(
      box: box,
      correctStreak: state.correctStreak + 1,
      nextDue: calendar.startOfDay(
        answer.answeredAt,
        plusDays: intervalDays[box],
      ),
    );
  }
}
