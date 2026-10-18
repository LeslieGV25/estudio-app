import 'package:rational/rational.dart';

import '../domain/exam_paper.dart';
import '../domain/score_calculator.dart';
import '../domain/usecases/load_exam_result.dart';

// Textos del simulacro, como funciones puras para poder probarlos sin
// pantallas. Los números se muestran con coma decimal.

/// «4.750» → «4,750»; «-2.500» → «−2,500».
String formatScore(String scoreText) =>
    scoreText.replaceFirst('.', ',').replaceFirst('-', '−');

/// Fracción con hasta [decimals] decimales: 1/4 → «0,25»; 5/4 → «1,25».
String formatRational(Rational value, {int decimals = 2}) =>
    formatScore(ScoreCalculator.roundHalfUp(value, decimals).toString());

/// Nota de un ejercicio. Si el pack anuló preguntas después de entregar, la
/// de hoy no coincide con la guardada y se muestran las dos.
String? partScoreText(ExamPartResult part) {
  final score = part.score;
  if (score == null) return null;
  final now = formatScore(score.scoreText);
  if (!part.scoreChangedSinceSubmit) return now;
  return '$now (recalculada; al entregar: '
      '${formatScore(part.submittedScoreText!)})';
}

/// «Te faltaban 1,25 aciertos netos para el 5,000»; `null` si aprueba o no
/// hay nota mínima.
String? missingText(ExamScore score) {
  final missing = score.missingNetCorrect;
  if (missing == null) return null;
  final amount = formatRational(missing);
  final unit = missing == Rational.one ? 'acierto neto' : 'aciertos netos';
  final passMark = formatScore(score.passMark!.toStringAsFixed(score.decimals));
  return 'Te faltaban $amount $unit para el $passMark';
}

/// Valor de cada respuesta, con los decimales del ejercicio:
/// «Acierto +0,200 · fallo −0,050 · en blanco 0,000».
String valuesText(ExamScore score) {
  String signed(Rational v) {
    final text = formatScore(
      ScoreCalculator.roundHalfUp(
        v,
        score.decimals,
      ).toStringAsFixed(score.decimals),
    );
    return v > Rational.zero ? '+$text' : text;
  }

  return 'Acierto ${signed(score.correctValue)} · '
      'fallo ${signed(score.wrongValue)} · '
      'en blanco ${signed(score.blankValue)}';
}

/// Lo que hay que saber de un ejercicio antes de empezarlo.
List<String> paperFacts(ExamPaper paper) {
  final count = paper.questionIds.length;
  final unreplaced = paper.unreplacedVoidedIds.length;
  return [
    '$count ${count == 1 ? 'pregunta' : 'preguntas'} · '
        '${paper.durationMin == null ? 'sin límite de tiempo' : '${paper.durationMin} min'}',
    if (paper.replacements.isNotEmpty)
      'Anuladas sustituidas por reserva: ${paper.replacements.length}',
    if (unreplaced > 0)
      'Anuladas sin reserva: $unreplaced (no puntúan; '
          '$count valorables)',
    if (count + unreplaced < paper.questionCount)
      'El pack tiene ${count + unreplaced} de las '
          '${paper.questionCount} preguntas del examen',
  ];
}

/// Tiempo restante: «54:07», o «1:05:03» con horas. Nunca negativo.
String formatRemaining(Duration remaining) {
  final d = remaining.isNegative ? Duration.zero : remaining;
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = d.inMinutes.remainder(60);
  final seconds = two(d.inSeconds.remainder(60));
  return d.inHours > 0
      ? '${d.inHours}:${two(minutes)}:$seconds'
      : '${two(d.inMinutes)}:$seconds';
}

String statusText(ExamPartStatus status) => switch (status) {
  ExamPartStatus.graded => 'Corregido',
  ExamPartStatus.notCorrected =>
    'No corregido: no se superó el ejercicio anterior',
  ExamPartStatus.inProgress => 'Sin entregar',
  ExamPartStatus.notTaken => 'No realizado',
};
