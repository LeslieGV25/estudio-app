import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/exam/domain/exam_paper.dart';
import 'package:estudio_app/features/exam/domain/score_calculator.dart';
import 'package:estudio_app/features/exam/domain/usecases/load_exam_result.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/progress/domain/entities/study_session.dart';
import 'package:estudio_app/features/stats/domain/pack_stats.dart';
import 'package:estudio_app/features/stats/domain/stats_filter.dart';
import 'package:estudio_app/features/stats/presentation/stats_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterSummary', () {
    test('por defecto', () {
      expect(
        filterSummary(const StatsFilter()),
        'Todos los modos · todas las fuentes',
      );
    });

    test('varios modos, oficiales y con obsoletas', () {
      expect(
        filterSummary(
          const StatsFilter(
            modes: {SessionMode.review, SessionMode.practice},
            sources: SourceFilter.official,
            includeObsolete: true,
          ),
        ),
        'Práctica y repaso · oficiales · con obsoletas',
      );
    });

    test('un solo modo', () {
      expect(
        filterSummary(
          const StatsFilter(
            modes: {SessionMode.exam},
            sources: SourceFilter.study,
          ),
        ),
        'Simulacro · de estudio',
      );
    });
  });

  test('averageTimeText', () {
    expect(averageTimeText(null), '—');
    expect(averageTimeText(const Duration(milliseconds: 12400)), '12 s');
    expect(averageTimeText(const Duration(seconds: 60)), '1 min');
    expect(averageTimeText(const Duration(seconds: 65)), '1 min 5 s');
  });

  test('coverageText', () {
    expect(
      coverageText(const Coverage(seen: 3, practicable: 7)),
      '3 de 7 (43 %)',
    );
    expect(
      coverageText(const Coverage(seen: 0, practicable: 0)),
      '0 de 0 (0 %)',
    );
  });

  test('topicTallyText', () {
    expect(
      topicTallyText(const AnswerTally(correct: 4, wrong: 8)),
      '33 % de aciertos · 12 respuestas',
    );
    expect(
      topicTallyText(const AnswerTally(correct: 1)),
      '100 % de aciertos · 1 respuesta',
    );
  });

  test('fechas en hora local', () {
    expect(shortDate(DateTime(2026, 3, 5)), '05/03');
    expect(dateTimeText(DateTime(2026, 10, 23, 9, 5)), '23/10/2026, 9:05');
  });

  group('daysSemantics', () {
    DayStats day(int d, [AnswerTally tally = AnswerTally.empty]) =>
        DayStats(DateTime.utc(2026, 10, d), tally);

    test('sin respuestas', () {
      expect(
        daysSemantics([day(1), day(2)]),
        'Sin respuestas en los últimos 2 días.',
      );
    });

    test('con respuestas', () {
      expect(
        daysSemantics([
          day(1, const AnswerTally(correct: 3, wrong: 1)),
          day(2),
          day(3, const AnswerTally(correct: 1, blank: 3)),
        ]),
        'Últimos 3 días: 8 respuestas en 2 días, 50 % de aciertos.',
      );
    });
  });

  group('examPartText', () {
    const paper = ExamPaper(
      exerciseId: 'ej1',
      name: 'Primer ejercicio',
      questionCount: 50,
      questionIds: [],
    );
    final session = StudySession(
      id: 's',
      packId: 'p',
      mode: SessionMode.exam,
      config: const {},
      startedAt: DateTime.utc(2026),
      finishedAt: DateTime.utc(2026),
      score: '4.750',
    );

    test('corregido: nota y veredicto', () {
      final score = ScoreCalculator.score(
        const Scoring(
          mode: ScoringMode.proportional,
          maxScore: 10,
          wrongFactor: 0.25,
          passMark: 5,
          decimals: 3,
        ),
        const ExamTally(correct: 29, wrong: 21, blank: 0),
      );

      expect(
        examPartText(
          ExamPartResult(
            paper: paper,
            status: ExamPartStatus.graded,
            session: session,
            score: score,
          ),
        ),
        'Primer ejercicio: 4,750 · NO APTO',
      );
    });

    test('sin corregir, sin entregar o no realizado', () {
      String text(ExamPartStatus status) =>
          examPartText(ExamPartResult(paper: paper, status: status));

      expect(
        text(ExamPartStatus.notCorrected),
        'Primer ejercicio: no corregido',
      );
      expect(text(ExamPartStatus.inProgress), 'Primer ejercicio: sin entregar');
      expect(text(ExamPartStatus.notTaken), 'Primer ejercicio: no realizado');
    });
  });
}
