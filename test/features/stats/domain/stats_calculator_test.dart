import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_outline.dart';
import 'package:estudio_app/features/packs/domain/entities/study_question.dart';
import 'package:estudio_app/features/progress/domain/entities/answer.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:estudio_app/features/stats/domain/pack_stats.dart';
import 'package:estudio_app/features/stats/domain/stats_calculator.dart';
import 'package:estudio_app/features/stats/domain/stats_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/review.dart';
import '../../../helpers/study_questions.dart';

void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  final now = cal.at(2026, 10, 23, 18);

  /// Bloque 1: temas 1 y 2. Bloque 2: temas 3 y 4.
  const outline = PackOutline(
    blocks: [
      Block(id: 1, name: 'Bloque 1'),
      Block(id: 2, name: 'Bloque 2'),
    ],
    topics: [
      Topic(id: 1, blockId: 1, title: 'Tema 1'),
      Topic(id: 2, blockId: 1, title: 'Tema 2'),
      Topic(id: 3, blockId: 2, title: 'Tema 3'),
      Topic(id: 4, blockId: 2, title: 'Tema 4'),
    ],
    sources: [],
  );

  StudyQuestion q(
    String id, {
    int topicId = 1,
    bool isOfficial = true,
    bool voided = false,
    bool obsolete = false,
  }) => studyQuestion(
    id,
    topicId: topicId,
    blockId: topicId <= 2 ? 1 : 2,
    isOfficial: isOfficial,
    voided: voided,
    obsolete: obsolete,
  );

  /// [n] respuestas a [questionId], [correct] de ellas acertadas y el resto
  /// falladas, separadas un minuto desde [from] (por defecto, hoy a las 10).
  List<Answer> answers(
    String questionId, {
    required int n,
    required int correct,
    DateTime? from,
  }) {
    final start = from ?? cal.at(2026, 10, 23, 10);
    return [
      for (var i = 0; i < n; i++)
        reviewAnswer(
          start.add(Duration(minutes: i)),
          questionId: questionId,
          correct: i < correct,
        ),
    ];
  }

  PackStats compute(
    List<StudyQuestion> questions,
    List<Answer> answers, {
    StatsFilter filter = const StatsFilter(),
    Map<String, ReviewState> reviewStates = const {},
    DateTime? since,
  }) => StatsCalculator.compute(
    outline: outline,
    questions: questions,
    answers: answers,
    reviewStates: reviewStates,
    filter: filter,
    now: now,
    calendar: cal,
    since: since,
  );

  test('ejemplo: un tema débil y un tema sin practicar', () {
    // Tema 1: 12 respuestas, 4 aciertos (33 %). Tema 2: 10 respuestas,
    // 9 aciertos (90 %). Tema 3: 3 respuestas (no llega al mínimo de 10).
    // Tema 4: tiene preguntas, pero ninguna respuesta.
    final questions = [
      q('t1-a'),
      q('t1-b'),
      q('t2-a', topicId: 2),
      q('t3-a', topicId: 3),
      q('t3-b', topicId: 3),
      q('t4-a', topicId: 4),
      q('t4-b', topicId: 4),
    ];
    final stats = compute(questions, [
      ...answers('t1-a', n: 12, correct: 4),
      ...answers('t2-a', n: 10, correct: 9),
      ...answers('t3-a', n: 3, correct: 0),
    ]);

    expect(stats.tally.counted, 25);
    expect(stats.tally.correct, 13);
    expect(stats.coverage.seen, 3);
    expect(stats.coverage.practicable, 7);

    // Umbral: max(60 %, 52 % global) = 60 %. El tema 2 (90 %) no es débil
    // y el tema 3 no llega a 10 respuestas.
    expect(stats.tally.correctPercent, 52);
    expect([for (final t in stats.weakTopics) t.topic.id], [1]);
    expect(stats.weakTopics.single.tally.correctPercent, closeTo(33.3, 0.1));
    expect([for (final t in stats.unpracticedTopics) t.topic.id], [4]);
    final tema4 = stats.topics.singleWhere((t) => t.topic.id == 4);
    expect(tema4.coverage.seen, 0);
    expect(tema4.coverage.practicable, 2);
  });

  group('respuestas que cuentan', () {
    test('cuenta cada respuesta, también las repetidas', () {
      final stats = compute(
        [q('q1')],
        [
          reviewAnswer(now, correct: false),
          reviewAnswer(now),
          reviewAnswer(now, blank: true),
          reviewAnswer(now),
        ],
      );

      expect(stats.tally.counted, 4);
      expect(stats.tally.correctPercent, 50);
      expect(stats.tally.wrongPercent, 25);
      expect(stats.tally.blankPercent, 25);
      expect(stats.tally.averageTime, const Duration(seconds: 1));
      expect(stats.coverage.seen, 1);
    });

    test('anuladas y preguntas que ya no están: «no cuentan»', () {
      final stats = compute(
        [q('q1'), q('anulada', voided: true)],
        [
          reviewAnswer(now),
          reviewAnswer(now, questionId: 'anulada'),
          reviewAnswer(now, questionId: 'quitada'),
        ],
      );

      expect(stats.tally.counted, 1);
      expect(stats.notCounted, 2);
      // La anulada tampoco es practicable.
      expect(stats.coverage.practicable, 1);
    });

    test('las obsoletas no entran salvo que se pidan', () {
      final questions = [q('q1'), q('vieja', obsolete: true)];
      final all = [reviewAnswer(now), reviewAnswer(now, questionId: 'vieja')];

      final byDefault = compute(questions, all);
      final withObsolete = compute(
        questions,
        all,
        filter: const StatsFilter(includeObsolete: true),
      );

      expect(byDefault.tally.counted, 1);
      expect(byDefault.notCounted, 0);
      expect(byDefault.coverage.practicable, 1);
      expect(withObsolete.tally.counted, 2);
      expect(withObsolete.coverage.practicable, 2);
    });

    test('filtro de fuentes: oficiales o de estudio', () {
      final questions = [q('oficial'), q('estudio', isOfficial: false)];
      final all = [
        reviewAnswer(now, questionId: 'oficial'),
        reviewAnswer(now, questionId: 'estudio', correct: false),
      ];

      final official = compute(
        questions,
        all,
        filter: const StatsFilter(sources: SourceFilter.official),
      );
      final study = compute(
        questions,
        all,
        filter: const StatsFilter(sources: SourceFilter.study),
      );

      expect(official.tally.correct, 1);
      expect(official.tally.counted, 1);
      expect(study.tally.wrong, 1);
      expect(study.tally.counted, 1);
    });

    test('con since, solo cuentan las respuestas desde ese instante', () {
      final stats = compute(
        [q('q1')],
        [
          reviewAnswer(cal.at(2026, 10, 1, 9), correct: false),
          reviewAnswer(cal.at(2026, 10, 20, 9)),
        ],
        since: cal.at(2026, 10, 10),
      );

      expect(stats.tally.counted, 1);
      expect(stats.tally.correct, 1);
    });

    test('sin respuestas, todo a cero', () {
      final stats = compute([q('q1')], const []);

      expect(stats.tally.counted, 0);
      expect(stats.tally.correctPercent, 0);
      expect(stats.tally.averageTime, isNull);
      expect(stats.coverage.percent, 0);
      expect(stats.studyDays, 0);
      expect(stats.weakTopics, isEmpty);
    });
  });

  group('temas y bloques', () {
    test('en el orden del pack, sin temas que no tienen nada', () {
      final stats = compute(
        [q('t3', topicId: 3), q('t1'), q('t2', topicId: 2)],
        [reviewAnswer(now, questionId: 't3')],
      );

      expect([for (final b in stats.blocks) b.block.id], [1, 2]);
      expect(
        [
          for (final b in stats.blocks) [for (final t in b.topics) t.topic.id],
        ],
        [
          [1, 2],
          [3],
        ],
      );
    });

    test('el bloque suma las respuestas y la cobertura de sus temas', () {
      final stats = compute(
        [q('t1-a'), q('t1-b'), q('t2', topicId: 2)],
        [
          reviewAnswer(now, questionId: 't1-a'),
          reviewAnswer(now, questionId: 't1-a', correct: false),
          reviewAnswer(now, questionId: 't2'),
        ],
      );

      final block = stats.blocks.single;
      expect(block.tally.counted, 3);
      expect(block.tally.correct, 2);
      expect(block.coverage.seen, 2);
      expect(block.coverage.practicable, 3);
      expect(block.coverage.percent, closeTo(66.7, 0.1));
    });

    test('un tema solo con anuladas no sale ni como sin practicar', () {
      final stats = compute([
        q('t1'),
        q('t2', topicId: 2, voided: true),
      ], const []);

      expect([for (final t in stats.topics) t.topic.id], [1]);
      expect([for (final t in stats.unpracticedTopics) t.topic.id], [1]);
    });

    test('responder solo anuladas de un tema no lo saca de sin practicar', () {
      final stats = compute(
        [q('t1'), q('t1-anulada', voided: true)],
        [reviewAnswer(now, questionId: 't1-anulada')],
      );

      expect([for (final t in stats.unpracticedTopics) t.topic.id], [1]);
    });
  });

  group('temas débiles', () {
    test('hacen falta 10 respuestas', () {
      final stats = compute(
        [q('t1'), q('t2', topicId: 2)],
        [
          ...answers('t1', n: 9, correct: 0),
          ...answers('t2', n: 10, correct: 3),
        ],
      );

      expect([for (final t in stats.weakTopics) t.topic.id], [2]);
    });

    test('media alta (85 %): débil es lo que va peor que la media', () {
      // 19/20 (95 %), 8/10 (80 %) y 7/10 (70 %): 34/40 = 85 % global.
      final stats = compute(
        [q('t1'), q('t2', topicId: 2), q('t3', topicId: 3)],
        [
          ...answers('t1', n: 20, correct: 19),
          ...answers('t2', n: 10, correct: 8),
          ...answers('t3', n: 10, correct: 7),
        ],
      );

      expect(stats.tally.correctPercent, 85);
      // 80 % y 70 % superan el 60 %, pero están por debajo de la media.
      expect([for (final t in stats.weakTopics) t.topic.id], [3, 2]);
    });

    test('media baja (40 %): débil es lo que no llega al 60 %', () {
      // 5/10 (50 %), 1/10 (10 %) y 6/10 (60 %): 12/30 = 40 % global.
      final stats = compute(
        [q('t1'), q('t2', topicId: 2), q('t3', topicId: 3)],
        [
          ...answers('t1', n: 10, correct: 5),
          ...answers('t2', n: 10, correct: 1),
          ...answers('t3', n: 10, correct: 6),
        ],
      );

      expect(stats.tally.correctPercent, 40);
      // El 50 % supera la media, pero no llega al 60 %. Justo el 60 % no
      // es débil: tiene que estar por debajo.
      expect([for (final t in stats.weakTopics) t.topic.id], [2, 1]);
    });

    test('a igual %, primero el que tiene más respuestas', () {
      final stats = compute(
        [q('t1'), q('t2', topicId: 2)],
        [
          ...answers('t1', n: 10, correct: 5),
          ...answers('t2', n: 20, correct: 10),
        ],
      );

      expect([for (final t in stats.weakTopics) t.topic.id], [2, 1]);
    });

    test('como mucho 5', () {
      // Hacen falta más de 5 temas débiles: 7, todos por debajo del 60 %.
      final bigOutline = PackOutline(
        blocks: const [Block(id: 1, name: 'Bloque 1')],
        topics: [
          for (var id = 1; id <= 7; id++)
            Topic(id: id, blockId: 1, title: 'Tema $id'),
        ],
        sources: const [],
      );
      final bigQuestions = [
        for (var id = 1; id <= 7; id++) studyQuestion('t$id', topicId: id),
      ];
      final stats = StatsCalculator.compute(
        outline: bigOutline,
        questions: bigQuestions,
        answers: [
          // Tema n: n aciertos de 20 (del 5 % al 35 %).
          for (var id = 1; id <= 7; id++)
            ...answers('t$id', n: 20, correct: id),
        ],
        reviewStates: const {},
        filter: const StatsFilter(),
        now: now,
        calendar: cal,
      );

      expect([for (final t in stats.weakTopics) t.topic.id], [1, 2, 3, 4, 5]);
    });
  });

  group('evolución por días', () {
    test('30 días hasta hoy, también los vacíos', () {
      final stats = compute([q('q1')], [reviewAnswer(now)]);

      expect(stats.days, hasLength(30));
      expect(stats.days.first.day, cal.at(2026, 9, 24));
      expect(stats.days.last.day, cal.at(2026, 10, 23));
      expect(stats.days.last.tally.counted, 1);
      expect(stats.days.where((d) => d.tally.counted == 0), hasLength(29));
    });

    test('el día es el de calendario local, no el de UTC', () {
      // 23:59 y 00:01 en Madrid (21:59 y 22:01 en UTC, el mismo día UTC).
      final stats = compute(
        [q('q1')],
        [
          reviewAnswer(cal.at(2026, 10, 21, 23, 59)),
          reviewAnswer(cal.at(2026, 10, 22, 0, 1), correct: false),
        ],
      );

      final byDay = {for (final d in stats.days) d.day: d.tally};
      expect(byDay[cal.at(2026, 10, 21)]!.correct, 1);
      expect(byDay[cal.at(2026, 10, 22)]!.wrong, 1);
      expect(stats.studyDays, 2);
    });

    test('lo anterior a la ventana cuenta en el total, no en los días', () {
      final stats = compute(
        [q('q1')],
        [reviewAnswer(cal.at(2026, 9, 23, 12)), reviewAnswer(now)],
      );

      expect(stats.tally.counted, 2);
      expect(stats.studyDays, 2);
      expect(stats.days.fold(0, (n, d) => n + d.tally.counted), 1);
    });
  });

  test('dominadas: solo preguntas que entran en el filtro', () {
    final mastered = ReviewState(box: 3, correctStreak: 3, nextDue: now);
    final learning = ReviewState(box: 1, correctStreak: 1, nextDue: now);

    final stats = compute(
      [q('q1'), q('q2'), q('anulada', voided: true)],
      const [],
      reviewStates: {'q1': mastered, 'q2': learning, 'anulada': mastered},
    );

    expect(stats.mastered, 1);
  });
}
