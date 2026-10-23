import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../exam/domain/exam_setup.dart';
import '../../exam/domain/usecases/load_exam_result.dart';
import '../../exam/presentation/exam_texts.dart';
import '../../practice/presentation/widgets/summary_sections.dart';
import '../domain/exam_history.dart';
import '../domain/pack_stats.dart';
import '../domain/stats_calculator.dart';
import '../domain/stats_filter.dart';

// Textos de las estadísticas, como funciones puras para poder probarlos sin
// pantallas. Las fechas llegan ya en hora local.

String sourceFilterLabel(SourceFilter sources) => switch (sources) {
  SourceFilter.all => 'Todas',
  SourceFilter.official => 'Oficiales',
  SourceFilter.study => 'De estudio',
};

/// «Todos los modos · todas las fuentes», «Práctica y repaso · oficiales ·
/// con obsoletas».
String filterSummary(StatsFilter filter) {
  final modes = [
    for (final mode in SessionMode.values)
      if (filter.modes.contains(mode)) mode.label,
  ];
  return [
    if (modes.length == SessionMode.values.length)
      'Todos los modos'
    else if (modes.length == 1)
      modes.single
    else
      '${modes.take(modes.length - 1).join(', ')} y '
          '${modes.last.toLowerCase()}',
    switch (filter.sources) {
      SourceFilter.all => 'todas las fuentes',
      SourceFilter.official => 'oficiales',
      SourceFilter.study => 'de estudio',
    },
    if (filter.includeObsolete) 'con obsoletas',
  ].join(' · ');
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

String answersText(int n) => _plural(n, 'respuesta', 'respuestas');

/// «3 de 7 (43 %)».
String coverageText(Coverage coverage) =>
    '${coverage.seen} de ${coverage.practicable} '
    '(${formatPercent(coverage.percent)})';

/// «—», «12 s», «1 min 5 s».
String averageTimeText(Duration? time) {
  if (time == null) return '—';
  final seconds = (time.inMilliseconds / 1000).round();
  if (seconds < 60) return '$seconds s';
  final rest = seconds % 60;
  return '${seconds ~/ 60} min${rest == 0 ? '' : ' $rest s'}';
}

/// «Tema 3 · Redes», como en el resumen de una sesión.
String topicTitle(TopicStats topic) =>
    'Tema ${topic.topic.id} · ${topic.topic.title}';

/// «33 % de aciertos · 12 respuestas».
String topicTallyText(AnswerTally tally) =>
    '${formatPercent(tally.correctPercent)} de aciertos · '
    '${answersText(tally.counted)}';

/// Regla de los temas débiles, para cuando no hay ninguno.
String get noWeakTopicsText =>
    'Ningún tema con al menos ${StatsCalculator.weakMinAnswers} respuestas '
    'está por debajo del ${StatsCalculator.weakFloorPercent} % ni de tu '
    'media.';

String _two(int n) => n.toString().padLeft(2, '0');

/// «23/10».
String shortDate(DateTime local) => '${_two(local.day)}/${_two(local.month)}';

/// «23/10/2026, 9:05».
String dateTimeText(DateTime local) =>
    '${shortDate(local)}/${local.year}, ${local.hour}:${_two(local.minute)}';

/// Resumen de los días para lectores de pantalla (el gráfico no se lee).
String daysSemantics(List<DayStats> days) {
  final total = days.fold(AnswerTally.empty, (sum, d) => sum + d.tally);
  final active = days.where((d) => d.tally.counted > 0).length;
  if (total.counted == 0) {
    return 'Sin respuestas en los últimos ${days.length} días.';
  }
  return 'Últimos ${days.length} días: ${answersText(total.counted)} en '
      '${_plural(active, 'día', 'días')}, '
      '${formatPercent(total.correctPercent)} de aciertos.';
}

/// «Examen real · Examen 2024 · completo», «Aleatorio · Ejercicio 1».
String examEntryTitle(ExamHistoryEntry entry) => [
  switch (entry.setup.kind) {
    ExamKind.realExam => 'Examen real',
    ExamKind.random => 'Aleatorio',
  },
  ?entry.sourceName,
  entry.isFull ? 'completo' : entry.result.parts.first.paper.name,
].join(' · ');

/// Una línea por ejercicio: «Ejercicio 1: 5,000 · APTO».
String examPartText(ExamPartResult part) {
  final name = part.paper.name;
  final status = switch (part.status) {
    ExamPartStatus.notCorrected => 'no corregido',
    ExamPartStatus.inProgress => 'sin entregar',
    ExamPartStatus.notTaken => 'no realizado',
    ExamPartStatus.graded => switch (part.score) {
      null => '${part.summary!.correct} de ${part.summary!.counted} aciertos',
      final score => [
        partScoreText(part)!,
        if (score.passed case final passed?) passed ? 'APTO' : 'NO APTO',
      ].join(' · '),
    },
  };
  return '$name: $status';
}

/// Para lectores de pantalla: la última nota de cada ejercicio.
String examChartSemantics(ExamHistory history) => [
  for (final series in history.series)
    '${series.name}: ${_plural(series.points.length, 'nota', 'notas')}, '
        'la última ${formatScore(series.points.last.scoreText)}',
].join('. ');
