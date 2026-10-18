import 'package:decimal/decimal.dart';
import 'package:estudio_app/features/exam/domain/score_calculator.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

void main() {
  // `puntuacion` de los dos ejercicios del pack de Zaragoza.
  const zaragoza = Scoring(
    mode: ScoringMode.proportional,
    maxScore: 10,
    wrongFactor: 0.25,
    blank: 0,
    passMark: 5,
    decimals: 3,
  );

  ExamScore score(
    Scoring scoring, {
    int correct = 0,
    int wrong = 0,
    int blank = 0,
  }) => ScoreCalculator.score(
    scoring,
    ExamTally(correct: correct, wrong: wrong, blank: blank),
  )!;

  Rational r(int n, [int d = 1]) => Rational.fromInt(n, d);

  group('proporcional (Zaragoza)', () {
    test('ej. 1, 50 valorables: acierto +0,200 y fallo −0,050', () {
      final s = score(zaragoza, correct: 30, wrong: 20);

      expect(s.correctValue, r(1, 5));
      expect(s.wrongValue, r(-1, 20));
      expect(s.blankValue, Rational.zero);
    });

    test('ej. 1 con 30 aciertos y 20 fallos → 5,000, apto', () {
      final s = score(zaragoza, correct: 30, wrong: 20);

      expect(s.scoreText, '5.000');
      expect(s.passed, isTrue);
      expect(s.missingNetCorrect, isNull);
    });

    test('ej. 1 con 29 aciertos y 21 fallos → 4,750, no apto', () {
      final s = score(zaragoza, correct: 29, wrong: 21);

      expect(s.scoreText, '4.750');
      expect(s.passed, isFalse);
      // 29 − 21·¼ = 23,75 netos; hacían falta 25.
      expect(s.missingNetCorrect, r(5, 4));
    });

    test('ej. 2, 25 valorables: acierto +0,400 y fallo −0,100', () {
      final s = score(zaragoza, correct: 15, wrong: 10);

      expect(s.correctValue, r(2, 5));
      expect(s.wrongValue, r(-1, 10));
    });

    test('ej. 2 con 15 aciertos y 10 fallos → 5,000', () {
      final s = score(zaragoza, correct: 15, wrong: 10);

      expect(s.scoreText, '5.000');
      expect(s.passed, isTrue);
    });

    test('en blanco no penaliza y cuenta como valorable', () {
      final s = score(zaragoza, correct: 25, blank: 25);

      expect(s.correctValue, r(1, 5));
      expect(s.scoreText, '5.000');
    });

    test('con 48 valorables se redondea solo al final', () {
      // Acierto = 10/48 = 5/24. 31 aciertos y 17 fallos:
      // (31 − 17/4)·5/24 = 107/4 · 5/24 = 535/96 = 5,572916…
      final s = score(zaragoza, correct: 31, wrong: 17);

      expect(s.correctValue, r(5, 24));
      expect(s.exact, r(535, 96));
      expect(s.scoreText, '5.573');
      // Redondeando antes el acierto a 0,208 saldría
      // 31·0,208 − 17·0,052 = 5,564: otra nota.
    });

    test('la nota puede ser negativa (no se corta en 0)', () {
      final s = score(zaragoza, correct: 1, wrong: 49);

      // (1 − 49/4)·10/50 = −45/4 · 1/5 = −2,25
      expect(s.scoreText, '-2.250');
      expect(s.passed, isFalse);
    });

    test('sin preguntas valorables no hay nota', () {
      expect(
        ScoreCalculator.score(
          zaragoza,
          const ExamTally(correct: 0, wrong: 0, blank: 0),
        ),
        isNull,
      );
    });
  });

  group('fijo', () {
    const fixed = Scoring(
      mode: ScoringMode.fixed,
      correct: 1,
      wrong: -0.33,
      blank: 0,
      passMark: 0.5,
      decimals: 2,
    );

    test('nota = aciertos·acierto + fallos·fallo + blancos·blanco', () {
      final s = score(fixed, correct: 10, wrong: 3, blank: 2);

      // 10 − 0,99 = 9,01
      expect(s.exact, r(901, 100));
      expect(s.scoreText, '9.01');
      expect(s.passed, isTrue);
    });

    test('los valores del pack se toman exactos, sin error de double', () {
      // 0.33 en double es 0,33000000000000001554…; si se arrastrara,
      // 100 fallos darían −33,0000000000000016 en vez de −33.
      final s = score(fixed, wrong: 100);

      expect(s.exact, r(-33));
    });

    test('el blanco puede penalizar si el pack lo dice', () {
      const withBlank = Scoring(
        mode: ScoringMode.fixed,
        correct: 1,
        wrong: -0.5,
        blank: -0.1,
      );

      expect(score(withBlank, correct: 2, blank: 5).exact, r(3, 2));
    });

    test('sin nota mínima no hay apto ni lo que faltaba', () {
      const noPassMark = Scoring(mode: ScoringMode.fixed, correct: 1, wrong: 0);

      final s = score(noPassMark, correct: 3);

      expect(s.passed, isNull);
      expect(s.missingNetCorrect, isNull);
    });

    test('sin decimales en el pack se usan 3', () {
      const noDecimals = Scoring(mode: ScoringMode.fixed, correct: 1, wrong: 0);

      expect(score(noDecimals, correct: 3).scoreText, '3.000');
    });

    test('falla si al modo fijo le falta el valor del acierto', () {
      const broken = Scoring(mode: ScoringMode.fixed, wrong: 0);

      expect(() => score(broken, correct: 1), throwsArgumentError);
    });
  });

  group('roundHalfUp', () {
    Decimal round(Rational value, int decimals) =>
        ScoreCalculator.roundHalfUp(value, decimals);

    test('el 5 sube (x,xxx5 → x,xx(x+1))', () {
      expect(round(r(40005, 10000), 3), Decimal.parse('4.001'));
      expect(round(r(1, 8), 2), Decimal.parse('0.13'));
    });

    test('simétrico: en negativos el 5 también se aleja del cero', () {
      expect(round(r(-40005, 10000), 3), Decimal.parse('-4.001'));
      expect(round(r(-1, 8), 2), Decimal.parse('-0.13'));
    });

    test('por debajo de la mitad baja', () {
      expect(round(r(40004, 10000), 3), Decimal.parse('4.000'));
      expect(round(r(2, 3), 3), Decimal.parse('0.667'));
      expect(round(r(1, 3), 3), Decimal.parse('0.333'));
    });

    test('un caso donde double falla: 1,0005 a 3 decimales', () {
      // En double 1.0005 es 1,000499999…, y redondearlo daría 1,000.
      expect(round(r(10005, 10000), 3), Decimal.parse('1.001'));
    });

    test('con 0 decimales', () {
      expect(round(r(5, 2), 0), Decimal.fromInt(3));
      expect(round(r(-5, 2), 0), Decimal.fromInt(-3));
    });
  });
}
