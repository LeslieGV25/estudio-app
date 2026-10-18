import 'dart:math';

import 'package:estudio_app/features/exam/domain/exam_plan.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_outline.dart';
import 'package:estudio_app/features/packs/domain/entities/study_question.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  const scoring = Scoring(
    mode: ScoringMode.proportional,
    maxScore: 10,
    wrongFactor: 0.25,
    passMark: 5,
    decimals: 3,
  );
  const rules = ExamRules(
    exercises: [
      ExamExercise(
        id: 'ej1',
        name: 'Primer ejercicio',
        questionCount: 4,
        reserveCount: 2,
        optionCount: 3,
        durationMin: 55,
        scoring: scoring,
      ),
      ExamExercise(
        id: 'ej2',
        name: 'Segundo ejercicio',
        questionCount: 3,
        optionCount: 4,
        hasCaseStudies: true,
      ),
    ],
  );

  Source source(String id, {bool official = true, List<String>? maps}) =>
      Source(
        id: id,
        type: official ? SourceType.exam : SourceType.study,
        name: id,
        isOfficial: official,
        exercises: [
          for (final (i, target) in (maps ?? const <String>[]).indexed)
            SourceExercise(
              id: 'e${i + 1}',
              name: 'Ejercicio ${i + 1}',
              optionCount: 3,
              examExerciseId: target,
            ),
        ],
      );

  final outline = PackOutline(
    blocks: const [],
    topics: const [],
    sources: [
      source('ex24', maps: ['ej1', 'ej2']),
      source('ex23', maps: ['ej1']),
      source('est', official: false, maps: ['ej1']),
      source('libre', official: false),
    ],
  );

  var position = 0;
  StudyQuestion q(
    String id, {
    String source = 'ex24',
    String exercise = 'e1',
    bool reserve = false,
    bool voided = false,
    bool obsolete = false,
    String? context,
  }) => studyQuestion(
    id,
    position: position++,
    sourceId: source,
    exerciseId: exercise,
    isOfficial: source.startsWith('ex'),
    isReserve: reserve,
    voided: voided,
    obsolete: obsolete,
    contextId: context,
  );

  ExamPlan build(
    List<StudyQuestion> questions, {
    ExamKind kind = ExamKind.realExam,
    String? sourceId = 'ex24',
    String? exerciseId,
    bool onlyOfficial = true,
    bool includeObsolete = false,
    int seed = 1,
  }) => ExamPlan.build(
    questions: questions,
    outline: outline,
    rules: rules,
    setup: ExamSetup(
      kind: kind,
      sourceId: kind == ExamKind.realExam ? sourceId : null,
      exerciseId: exerciseId,
      onlyOfficial: onlyOfficial,
      includeObsolete: includeObsolete,
    ),
    random: Random(seed),
  );

  setUp(() => position = 0);

  group('examen real', () {
    test('cada anulada se sustituye por la siguiente reserva, al final', () {
      final plan = build(exerciseId: 'ej1', [
        q('1'),
        q('2', voided: true),
        q('3'),
        q('4', voided: true),
        q('r1', reserve: true),
        q('r2', reserve: true),
        q('r3', reserve: true),
      ]);

      final paper = plan.papers.single;
      expect(paper.questionIds, ['1', '3', 'r1', 'r2']);
      expect(paper.voidedIds, ['2', '4']);
      expect(paper.replacements, {'2': 'r1', '4': 'r2'});
      expect(paper.unreplacedVoidedIds, isEmpty);
      expect(paper.isShort, isFalse);
    });

    test('sin reservas suficientes, la anulada resta una valorable', () {
      final plan = build(exerciseId: 'ej1', [
        q('1'),
        q('2', voided: true),
        q('3', voided: true),
        q('4'),
        q('r1', reserve: true),
      ]);

      final paper = plan.papers.single;
      expect(paper.questionIds, ['1', '4', 'r1']);
      expect(paper.unreplacedVoidedIds, ['3']);
      expect(paper.isShort, isTrue);
    });

    test('una reserva anulada no sustituye: pasa a la siguiente', () {
      final plan = build(exerciseId: 'ej1', [
        q('1', voided: true),
        q('r1', reserve: true, voided: true),
        q('r2', reserve: true),
      ]);

      expect(plan.papers.single.replacements, {'1': 'r2'});
    });

    test('sin anuladas no entra ninguna reserva', () {
      final plan = build(exerciseId: 'ej1', [
        q('1'),
        q('2'),
        q('r1', reserve: true),
      ]);

      expect(plan.papers.single.questionIds, ['1', '2']);
    });

    test('las obsoletas quedan fuera por defecto y no se sustituyen', () {
      final questions = [
        q('1'),
        q('2', obsolete: true),
        q('r1', reserve: true),
      ];

      expect(build(questions).papers.single.questionIds, ['1']);
      expect(
        build(questions, includeObsolete: true).papers.single.questionIds,
        ['1', '2'],
      );
    });

    test('solo entran preguntas de la fuente elegida', () {
      final plan = build(exerciseId: 'ej1', [
        q('a1'),
        q('b1', source: 'ex23'),
        q('a2'),
      ]);

      expect(plan.papers.single.questionIds, ['a1', 'a2']);
    });

    test('simulacro completo: un ejercicio tras otro, con sus reglas', () {
      final plan = build([q('1'), q('2', exercise: 'e2')]);

      // Los records comparan sus campos con ==, y dos listas solo son ==
      // si son la misma: se comparan unidas en un texto.
      expect(plan.papers.map((p) => (p.exerciseId, p.questionIds.join(','))), [
        ('ej1', '1'),
        ('ej2', '2'),
      ]);
      expect(plan.papers.first.durationMin, 55);
      expect(plan.papers.first.scoring, scoring);
      expect(plan.papers.last.durationMin, isNull);
      expect(plan.papers.last.scoring, isNull);
    });

    test('un ejercicio sin preguntas en esa fuente se omite', () {
      final plan = build(sourceId: 'ex23', [
        q('1', source: 'ex23'),
        q('2', exercise: 'e2'),
      ]);

      expect(plan.papers.map((p) => p.exerciseId), ['ej1']);
    });

    test('sin preguntas, el plan queda vacío', () {
      expect(build(exerciseId: 'ej2', [q('1')]).isEmpty, isTrue);
    });
  });

  group('aleatorio', () {
    final pool = [
      q('a1'),
      q('a2', voided: true),
      q('ar', reserve: true),
      q('b1', source: 'ex23'),
      q('b2', source: 'ex23', obsolete: true),
      q('s1', source: 'est', exercise: 'e1'),
      q('l1', source: 'libre', exercise: 'e1'),
    ];

    Set<String> ids(ExamPlan plan) => plan.papers.single.questionIds.toSet();

    test('todas las fuentes del ejercicio; reservas como normales', () {
      final plan = build(pool, kind: ExamKind.random, exerciseId: 'ej1');

      expect(ids(plan), {'a1', 'ar', 'b1'});
      expect(plan.papers.single.voidedIds, isEmpty);
    });

    test('con «solo oficiales» desactivado entran las de estudio', () {
      final plan = build(
        pool,
        kind: ExamKind.random,
        exerciseId: 'ej1',
        onlyOfficial: false,
      );

      // `libre` no equivale a ningún ejercicio: nunca entra.
      expect(ids(plan), {'a1', 'ar', 'b1', 's1'});
    });

    test('obsoletas solo si se piden', () {
      final plan = build(
        pool,
        kind: ExamKind.random,
        exerciseId: 'ej1',
        includeObsolete: true,
      );

      expect(ids(plan), contains('b2'));
    });

    test('recorta al nº de preguntas del ejercicio', () {
      final many = [for (var i = 0; i < 10; i++) q('p$i')];

      final paper = build(
        many,
        kind: ExamKind.random,
        exerciseId: 'ej1',
      ).papers.single;

      expect(paper.questionIds, hasLength(4));
      expect(paper.isShort, isFalse);
    });

    test('los supuestos van enteros y en su orden', () {
      final questions = [
        q('x1', exercise: 'e2', context: 'x'),
        q('x2', exercise: 'e2', context: 'x'),
        q('y1', exercise: 'e2', context: 'y'),
        q('y2', exercise: 'e2', context: 'y'),
        q('z1', exercise: 'e2'),
      ];

      for (var seed = 0; seed < 20; seed++) {
        final order = build(
          questions,
          kind: ExamKind.random,
          exerciseId: 'ej2',
          seed: seed,
        ).papers.single.questionIds;

        // 3 preguntas: un supuesto entero y la suelta.
        expect(order, hasLength(3));
        for (final (a, b) in [('x1', 'x2'), ('y1', 'y2')]) {
          if (order.contains(a)) {
            expect(order.indexOf(b), order.indexOf(a) + 1);
          }
        }
      }
    });

    test('con la misma semilla sale el mismo simulacro', () {
      final many = [for (var i = 0; i < 10; i++) q('p$i')];

      List<String> run() => build(
        many,
        kind: ExamKind.random,
        exerciseId: 'ej1',
        seed: 7,
      ).papers.single.questionIds;

      expect(run(), run());
    });
  });

  test('realExamSources: solo fuentes con ejercicios de simulacro', () {
    expect(ExamPlan.realExamSources(outline, rules).map((s) => s.id), [
      'ex24',
      'ex23',
      'est',
    ]);
  });
}
