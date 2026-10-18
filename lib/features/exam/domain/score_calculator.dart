import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import '../../packs/domain/entities/pack_document.dart';

/// Aciertos, fallos y en blanco de las preguntas valorables de un ejercicio
/// (sin anuladas: esas ni puntúan ni cuentan como valorables).
class ExamTally {
  const ExamTally({
    required this.correct,
    required this.wrong,
    required this.blank,
  });

  final int correct;
  final int wrong;
  final int blank;

  /// Preguntas valorables: todas las del ejercicio menos las anuladas que no
  /// sustituyó ninguna reserva.
  int get gradable => correct + wrong + blank;
}

/// Nota de un ejercicio. Todo se guarda exacto ([Rational]); solo la nota
/// final ([rounded]) está redondeada.
class ExamScore {
  const ExamScore({
    required this.correctValue,
    required this.wrongValue,
    required this.blankValue,
    required this.exact,
    required this.rounded,
    required this.decimals,
    required this.passMark,
  });

  /// Lo que suma o resta cada acierto, fallo y pregunta en blanco.
  final Rational correctValue;
  final Rational wrongValue;
  final Rational blankValue;

  /// Nota sin redondear.
  final Rational exact;

  /// Nota redondeada half-up a [decimals] decimales: la que se publica.
  final Decimal rounded;
  final int decimals;

  /// `null` si el ejercicio no tiene nota mínima.
  final Decimal? passMark;

  /// APTO / NO APTO; `null` si no hay nota mínima. Se compara la nota
  /// redondeada, que es la oficial.
  bool? get passed => passMark == null ? null : rounded >= passMark!;

  /// Aciertos netos que faltaban para aprobar (cuántos aciertos más, sin
  /// fallos extra, habrían hecho falta); `null` si aprueba o no hay mínima.
  Rational? get missingNetCorrect {
    if (passed != false || correctValue <= Rational.zero) return null;
    return (passMark!.toRational() - exact) / correctValue;
  }

  /// Nota con todos sus decimales («4.750»): es lo que se guarda en
  /// `sessions.score`.
  String get scoreText => rounded.toStringAsFixed(decimals);
}

/// Calcula la nota de un ejercicio de simulacro según su `puntuacion`.
///
/// - `fijo`: nota = aciertos·acierto + fallos·fallo + blancos·blanco.
/// - `proporcional`: acierto = nota_maxima / valorables;
///   fallo = −acierto·factor_fallo; blanco = el del pack (0 si no lo indica).
///
/// Se opera con fracciones exactas y se redondea **una sola vez, al final**:
/// con 48 valorables el acierto vale 10/48 = 0,208333…, y redondearlo antes
/// de multiplicar daría una nota distinta de la oficial.
abstract final class ScoreCalculator {
  /// Decimales si el pack no los indica.
  static const defaultDecimals = 3;

  /// `null` si el modo es proporcional y no queda ninguna pregunta valorable
  /// (no hay nota que dar).
  static ExamScore? score(Scoring scoring, ExamTally tally) {
    final Rational correctValue;
    final Rational wrongValue;
    final Rational blankValue = _rational(scoring.blank) ?? Rational.zero;
    switch (scoring.mode) {
      case ScoringMode.fixed:
        correctValue = _required(scoring.correct, 'acierto');
        wrongValue = _required(scoring.wrong, 'fallo');
      case ScoringMode.proportional:
        if (tally.gradable == 0) return null;
        correctValue =
            _required(scoring.maxScore, 'nota_maxima') /
            Rational.fromInt(tally.gradable);
        wrongValue =
            -correctValue * _required(scoring.wrongFactor, 'factor_fallo');
    }

    final exact =
        correctValue * Rational.fromInt(tally.correct) +
        wrongValue * Rational.fromInt(tally.wrong) +
        blankValue * Rational.fromInt(tally.blank);
    final decimals = scoring.decimals ?? defaultDecimals;
    return ExamScore(
      correctValue: correctValue,
      wrongValue: wrongValue,
      blankValue: blankValue,
      exact: exact,
      rounded: roundHalfUp(exact, decimals),
      decimals: decimals,
      passMark: _rational(scoring.passMark)?.toDecimal(),
    );
  }

  /// Redondeo aritmético simétrico: el 5 se aleja del cero
  /// (4,0005 → 4,001 y −4,0005 → −4,001).
  static Decimal roundHalfUp(Rational value, int decimals) {
    final scaled = value * Rational(BigInt.from(10).pow(decimals));
    // Rational.round() redondea al entero más cercano y, en el empate, se
    // aleja del cero: es exactamente el half-up simétrico.
    return Decimal.fromBigInt(scaled.round()).shift(-decimals);
  }

  // Los valores del pack llegan como double; su toString() es el número tal
  // como se escribió en el JSON (0.25 → "0.25"), así que no arrastra el error
  // binario del double.
  static Rational? _rational(double? value) =>
      value == null ? null : Decimal.parse(value.toString()).toRational();

  static Rational _required(double? value, String field) =>
      _rational(value) ??
      (throw ArgumentError('La puntuación no indica «$field»'));
}
