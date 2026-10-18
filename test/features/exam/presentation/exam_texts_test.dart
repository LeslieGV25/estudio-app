import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/exam/domain/exam_paper.dart';
import 'package:estudio_app/features/exam/domain/score_calculator.dart';
import 'package:estudio_app/features/exam/domain/usecases/load_exam_result.dart';
import 'package:estudio_app/features/exam/presentation/exam_texts.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/progress/domain/entities/study_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

void main() {
  const zaragoza = Scoring(
    mode: ScoringMode.proportional,
    maxScore: 10,
    wrongFactor: 0.25,
    passMark: 5,
    decimals: 3,
  );

  ExamScore score(int correct, int wrong, [int blank = 0]) =>
      ScoreCalculator.score(
        zaragoza,
        ExamTally(correct: correct, wrong: wrong, blank: blank),
      )!;

  const paper = ExamPaper(
    exerciseId: 'ej1',
    name: 'Primer ejercicio',
    questionCount: 50,
    questionIds: [],
  );

  ExamPartResult part({required String? stored, required ExamScore score}) =>
      ExamPartResult(
        paper: paper,
        status: ExamPartStatus.graded,
        session: StudySession(
          id: 's',
          packId: 'p',
          mode: SessionMode.exam,
          config: const {},
          startedAt: DateTime.utc(2026),
          finishedAt: DateTime.utc(2026),
          score: stored,
        ),
        score: score,
      );

  test('formatScore: coma decimal y signo menos tipográfico', () {
    expect(formatScore('4.750'), '4,750');
    expect(formatScore('-2.500'), '−2,500');
  });

  test('formatRational', () {
    expect(formatRational(Rational.fromInt(1, 4)), '0,25');
    expect(formatRational(Rational.fromInt(5, 4)), '1,25');
    expect(formatRational(Rational.fromInt(1, 3)), '0,33');
  });

  group('partScoreText', () {
    test('si coincide con la guardada, solo la nota', () {
      expect(
        partScoreText(part(stored: '5.000', score: score(30, 20))),
        '5,000',
      );
    });

    test('si difiere, las dos con su etiqueta', () {
      // 34 aciertos y 16 fallos = 6,8 − 0,8 = 6,000; al entregar se
      // guardó 5,875.
      expect(
        partScoreText(part(stored: '5.875', score: score(34, 16))),
        '6,000 (recalculada; al entregar: 5,875)',
      );
    });
  });

  test('missingText', () {
    expect(
      missingText(score(29, 21)),
      'Te faltaban 1,25 aciertos netos para el 5,000',
    );
    expect(missingText(score(30, 20)), isNull);
  });

  test('valuesText', () {
    expect(
      valuesText(score(30, 20)),
      'Acierto +0,200 · fallo −0,050 · en blanco 0,000',
    );
  });

  group('paperFacts', () {
    test('ejercicio con reservas usadas', () {
      expect(
        paperFacts(
          paper.copyWith(
            questionIds: List.generate(50, (i) => 'q$i'),
            voidedIds: ['a', 'b'],
            replacements: {'a': 'r1', 'b': 'r2'},
            durationMin: 55,
          ),
        ),
        ['50 preguntas · 55 min', 'Anuladas sustituidas por reserva: 2'],
      );
    });

    test('anuladas sin reserva restan valorables', () {
      expect(
        paperFacts(
          paper.copyWith(
            questionCount: 25,
            questionIds: List.generate(21, (i) => 'q$i'),
            voidedIds: ['a', 'b', 'c', 'd'],
            durationMin: 35,
          ),
        ),
        [
          '21 preguntas · 35 min',
          'Anuladas sin reserva: 4 (no puntúan; 21 valorables)',
        ],
      );
    });

    test('examen incompleto en el pack, sin tiempo', () {
      expect(
        paperFacts(
          paper.copyWith(questionIds: List.generate(20, (i) => 'q$i')),
        ),
        [
          '20 preguntas · sin límite de tiempo',
          'El pack tiene 20 de las 50 preguntas del examen',
        ],
      );
    });
  });

  test('formatRemaining', () {
    expect(formatRemaining(const Duration(minutes: 54, seconds: 7)), '54:07');
    expect(
      formatRemaining(const Duration(hours: 1, minutes: 5, seconds: 3)),
      '1:05:03',
    );
    expect(formatRemaining(const Duration(seconds: -3)), '00:00');
  });
}
