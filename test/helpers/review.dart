import 'package:estudio_app/features/progress/domain/entities/answer.dart';
import 'package:estudio_app/features/review/domain/review_calendar.dart';

/// Calendario con un desfase fijo respecto a UTC (sin cambios de hora), para
/// que los tests den lo mismo en cualquier máquina y en el CI.
class FixedOffsetCalendar implements ReviewCalendar {
  const FixedOffsetCalendar(this.offset);

  /// Hora de Madrid en verano.
  static const madridSummer = FixedOffsetCalendar(Duration(hours: 2));

  final Duration offset;

  @override
  DateTime startOfDay(DateTime instant, {int plusDays = 0}) {
    final local = instant.toUtc().add(offset);
    return DateTime.utc(
      local.year,
      local.month,
      local.day + plusDays,
    ).subtract(offset);
  }

  /// Instante (UTC) de una hora local de este calendario.
  DateTime at(int year, int month, int day, [int hour = 0, int minute = 0]) =>
      DateTime.utc(year, month, day, hour, minute).subtract(offset);
}

/// Respuesta mínima para tests de repaso: acierto por defecto,
/// `correct: false` = fallo y `blank: true` = en blanco.
Answer reviewAnswer(
  DateTime answeredAt, {
  bool correct = true,
  bool blank = false,
  String questionId = 'q1',
  String sessionId = 's1',
  String packId = 'pack',
}) => Answer(
  id: '${questionId}_${answeredAt.toIso8601String()}',
  sessionId: sessionId,
  packId: packId,
  questionId: questionId,
  chosen: blank ? null : (correct ? 'a' : 'b'),
  isCorrect: !blank && correct,
  timeMs: 1000,
  answeredAt: answeredAt,
);
