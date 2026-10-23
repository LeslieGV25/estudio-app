import '../../packs/domain/entities/pack_outline.dart';
import '../../packs/domain/entities/study_question.dart';
import '../../progress/domain/entities/answer.dart';
import '../../review/domain/review_calendar.dart';
import '../../review/domain/review_state.dart';
import 'pack_stats.dart';
import 'stats_filter.dart';

/// Calcula las estadísticas de un pack a partir de sus preguntas y de las
/// respuestas guardadas. Es una función pura: las reglas se prueban sin
/// base de datos.
///
/// - Cuenta **cada respuesta**, también las repetidas: se miden intentos.
/// - Las respuestas a preguntas anuladas hoy o que ya no están en el pack
///   «no cuentan» ([PackStats.notCounted]); las de preguntas que el filtro
///   deja fuera (obsoletas, fuente) simplemente no entran.
/// - Los porcentajes se calculan sobre aciertos + fallos + en blanco, como en
///   el resumen de una sesión.
abstract final class StatsCalculator {
  /// Respuestas mínimas para que un tema pueda salir como débil: con menos,
  /// un solo fallo lo pondría el primero.
  static const weakMinAnswers = 10;
  static const weakTopicCount = 5;

  /// Un tema es débil si su % de aciertos está por debajo de
  /// max(weakFloorPercent, % global). El 60 % es lo que hace falta en el
  /// ej. 1 de Zaragoza contestando todo para llegar al 5 (30 de 50: +6 − 1).
  /// Con una media alta, débil es lo que va peor que la media; con una media
  /// baja, lo que no llegaría al aprobado.
  static const weakFloorPercent = 60;

  /// Días que se muestran en la evolución diaria (hoy incluido).
  static const windowDays = 30;

  /// [answers] ya vienen filtradas por los modos de [filter] (lo hace el
  /// repositorio). Con [since], solo cuentan las respuestas desde ese
  /// instante (para el reinicio de progreso de la Fase 6).
  static PackStats compute({
    required PackOutline outline,
    required List<StudyQuestion> questions,
    required List<Answer> answers,
    required Map<String, ReviewState> reviewStates,
    required StatsFilter filter,
    required DateTime now,
    required ReviewCalendar calendar,
    DateTime? since,
  }) {
    final byId = {for (final q in questions) q.id: q};
    final included = {
      for (final q in questions)
        if (filter.matches(q)) q.id: q,
    };

    var notCounted = 0;
    var total = AnswerTally.empty;
    final byTopic = <int, AnswerTally>{};
    final seenByTopic = <int, Set<String>>{};
    final byDay = <DateTime, AnswerTally>{};

    for (final answer in answers) {
      if (since != null && answer.answeredAt.isBefore(since)) continue;
      final question = byId[answer.questionId];
      if (question == null || question.question.voided) {
        notCounted++;
        continue;
      }
      if (!included.containsKey(question.id)) continue;

      final one = _tallyOf(answer);
      total += one;
      byTopic.update(question.topicId, (t) => t + one, ifAbsent: () => one);
      seenByTopic.putIfAbsent(question.topicId, () => {}).add(question.id);
      byDay.update(
        calendar.startOfDay(answer.answeredAt),
        (t) => t + one,
        ifAbsent: () => one,
      );
    }

    final practicableByTopic = <int, int>{};
    for (final q in included.values) {
      practicableByTopic.update(q.topicId, (n) => n + 1, ifAbsent: () => 1);
    }

    final topicsByBlock = <int, List<TopicStats>>{};
    for (final topic in outline.topics) {
      final tally = byTopic[topic.id] ?? AnswerTally.empty;
      final practicable = practicableByTopic[topic.id] ?? 0;
      if (practicable == 0 && tally.counted == 0) continue;
      topicsByBlock
          .putIfAbsent(topic.blockId, () => [])
          .add(
            TopicStats(
              topic: topic,
              tally: tally,
              coverage: Coverage(
                seen: seenByTopic[topic.id]?.length ?? 0,
                practicable: practicable,
              ),
            ),
          );
    }
    final blocks = [
      for (final block in outline.blocks)
        if (topicsByBlock[block.id] case final topics?)
          BlockStats(block: block, topics: List.unmodifiable(topics)),
    ];
    final topics = [for (final b in blocks) ...b.topics];

    // Del día más antiguo de la ventana a hoy.
    final days = List.generate(windowDays, (i) {
      final day = calendar.startOfDay(now, plusDays: i - windowDays + 1);
      return DayStats(day, byDay[day] ?? AnswerTally.empty);
    });

    return PackStats(
      tally: total,
      notCounted: notCounted,
      coverage: topics.fold(
        const Coverage(seen: 0, practicable: 0),
        (sum, t) => sum + t.coverage,
      ),
      mastered: reviewStates.entries
          .where((e) => included.containsKey(e.key) && e.value.isMastered)
          .length,
      studyDays: byDay.length,
      blocks: List.unmodifiable(blocks),
      days: List.unmodifiable(days),
      weakTopics: List.unmodifiable(_weakTopics(topics, total)),
      unpracticedTopics: List.unmodifiable([
        for (final t in topics)
          if (t.isUnpracticed && t.coverage.practicable > 0) t,
      ]),
    );
  }

  static AnswerTally _tallyOf(Answer answer) => AnswerTally(
    correct: answer.isCorrect ? 1 : 0,
    wrong: !answer.isCorrect && !answer.isBlank ? 1 : 0,
    blank: answer.isBlank ? 1 : 0,
    totalTimeMs: answer.timeMs,
  );

  /// Temas por debajo de max([weakFloorPercent], % global), con al menos
  /// [weakMinAnswers] respuestas. Peor % de aciertos primero; a igualdad, el
  /// que tiene más respuestas (el dato es más fiable) y, al final, el orden
  /// del pack.
  static List<TopicStats> _weakTopics(
    List<TopicStats> topics,
    AnswerTally total,
  ) {
    final order = {for (final (i, t) in topics.indexed) t.topic.id: i};
    // x < max(a, b) ⇔ x < a o x < b. Todo en enteros, multiplicando en
    // cruz: correct / counted < 60 / 100 o < total.correct / total.counted.
    bool isWeak(AnswerTally t) =>
        t.counted >= weakMinAnswers &&
        (t.correct * 100 < weakFloorPercent * t.counted ||
            t.correct * total.counted < total.correct * t.counted);
    final candidates = [
      for (final t in topics)
        if (isWeak(t.tally)) t,
    ];
    candidates.sort((a, b) {
      // a.correct / a.counted frente a b.correct / b.counted, sin double.
      final byRatio = (a.tally.correct * b.tally.counted).compareTo(
        b.tally.correct * a.tally.counted,
      );
      if (byRatio != 0) return byRatio;
      final byCount = b.tally.counted.compareTo(a.tally.counted);
      if (byCount != 0) return byCount;
      return order[a.topic.id]!.compareTo(order[b.topic.id]!);
    });
    return candidates.take(weakTopicCount).toList();
  }
}
