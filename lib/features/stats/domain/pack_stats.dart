import '../../packs/domain/entities/pack_document.dart';

/// Aciertos, fallos y en blanco de un conjunto de respuestas que cuentan.
class AnswerTally {
  const AnswerTally({
    this.correct = 0,
    this.wrong = 0,
    this.blank = 0,
    this.totalTimeMs = 0,
  });

  static const empty = AnswerTally();

  final int correct;
  final int wrong;
  final int blank;

  /// Suma del tiempo de respuesta, para la media.
  final int totalTimeMs;

  /// Respuestas que entran en los porcentajes.
  int get counted => correct + wrong + blank;

  /// Porcentajes sobre [counted]; 0 si no hay ninguna.
  double get correctPercent => _percent(correct);
  double get wrongPercent => _percent(wrong);
  double get blankPercent => _percent(blank);

  /// Tiempo medio por respuesta; `null` si no hay ninguna.
  Duration? get averageTime => counted == 0
      ? null
      : Duration(milliseconds: (totalTimeMs / counted).round());

  AnswerTally operator +(AnswerTally other) => AnswerTally(
    correct: correct + other.correct,
    wrong: wrong + other.wrong,
    blank: blank + other.blank,
    totalTimeMs: totalTimeMs + other.totalTimeMs,
  );

  double _percent(int n) => counted == 0 ? 0 : n * 100 / counted;
}

/// Preguntas distintas respondidas frente a las que se pueden practicar.
class Coverage {
  const Coverage({required this.seen, required this.practicable});

  final int seen;
  final int practicable;

  /// 0 si no hay preguntas que practicar.
  double get percent => practicable == 0 ? 0 : seen * 100 / practicable;

  Coverage operator +(Coverage other) => Coverage(
    seen: seen + other.seen,
    practicable: practicable + other.practicable,
  );
}

class TopicStats {
  const TopicStats({
    required this.topic,
    required this.tally,
    required this.coverage,
  });

  final Topic topic;
  final AnswerTally tally;
  final Coverage coverage;

  /// Sin ninguna respuesta que cuente.
  bool get isUnpracticed => tally.counted == 0;
}

class BlockStats {
  const BlockStats({required this.block, required this.topics});

  final Block block;

  /// Temas del bloque en el orden del pack.
  final List<TopicStats> topics;

  AnswerTally get tally =>
      topics.fold(AnswerTally.empty, (sum, t) => sum + t.tally);

  Coverage get coverage => topics.fold(
    const Coverage(seen: 0, practicable: 0),
    (sum, t) => sum + t.coverage,
  );
}

/// Respuestas de un día de calendario de la usuaria.
class DayStats {
  const DayStats(this.day, this.tally);

  /// Medianoche local del día, en UTC.
  final DateTime day;
  final AnswerTally tally;
}

/// Estadísticas de un pack con un filtro (ver `StatsCalculator`).
class PackStats {
  const PackStats({
    required this.tally,
    required this.notCounted,
    required this.coverage,
    required this.mastered,
    required this.studyDays,
    required this.blocks,
    required this.days,
    required this.weakTopics,
    required this.unpracticedTopics,
  });

  /// Todas las respuestas que cuentan.
  final AnswerTally tally;

  /// Respuestas a preguntas anuladas o que ya no están en el pack.
  final int notCounted;

  final Coverage coverage;

  /// Preguntas dominadas en el repaso (3 aciertos seguidos).
  final int mastered;

  /// Días distintos con alguna respuesta que cuenta.
  final int studyDays;

  /// Bloques con sus temas, en el orden del pack. Solo temas con preguntas
  /// que practicar o con respuestas.
  final List<BlockStats> blocks;

  /// Últimos días, del más antiguo a hoy, también los días sin respuestas.
  final List<DayStats> days;

  /// Peor % de aciertos primero, entre los temas con bastantes respuestas.
  final List<TopicStats> weakTopics;

  /// Temas con preguntas que practicar y ninguna respuesta, en orden.
  final List<TopicStats> unpracticedTopics;

  List<TopicStats> get topics => [for (final b in blocks) ...b.topics];
}
