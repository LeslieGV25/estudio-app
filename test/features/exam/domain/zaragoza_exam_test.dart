import 'dart:math';

import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/exam/domain/exam_plan.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/exam/domain/score_calculator.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rational/rational.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

/// Simulacros con el pack real de Zaragoza: comprueba que las anuladas y las
/// reservas de los exámenes reales dan las preguntas valorables correctas.
void main() {
  late AppDatabase db;
  late DriftPackContentRepository content;
  late String packId;

  setUp(() async {
    db = newTestDatabase();
    final pack = loadPack(zaragozaPath);
    packId = pack.info.id;
    await DriftPackRepository(db).save(pack);
    content = DriftPackContentRepository(db);
  });
  tearDown(() => db.close());

  Future<ExamPlan> plan(ExamSetup setup) async => ExamPlan.build(
    questions: await content.questions(packId),
    outline: await content.outline(packId),
    rules: await content.examRules(packId),
    setup: setup,
    random: Random(1),
  );

  group('examen real de 2024 (zgz-2024-tl)', () {
    late ExamPlan exam;

    setUp(() async {
      exam = await plan(
        const ExamSetup(kind: ExamKind.realExam, sourceId: 'zgz-2024-tl'),
      );
    });

    test('ej. 1: 4 anuladas sustituidas por 4 de las 5 reservas → 50', () {
      final ej1 = exam.papers.first;

      expect(ej1.exerciseId, 'ej1');
      expect(ej1.voidedIds, hasLength(4));
      expect(ej1.replacements, hasLength(4));
      expect(ej1.questionIds, hasLength(50));
      expect(ej1.isShort, isFalse);
      expect(ej1.durationMin, 55);
    });

    test('ej. 2: 4 anuladas sin reserva → 21 valorables', () {
      final ej2 = exam.papers.last;

      expect(ej2.exerciseId, 'ej2');
      expect(ej2.voidedIds, hasLength(4));
      expect(ej2.unreplacedVoidedIds, hasLength(4));
      expect(ej2.questionIds, hasLength(21));
      expect(ej2.durationMin, 35);
    });

    test('ej. 2: acierto 10/21, fallo −5/42; 13 aciertos y 8 fallos', () {
      final ej2 = exam.papers.last;

      final score = ScoreCalculator.score(
        ej2.scoring!,
        const ExamTally(correct: 13, wrong: 8, blank: 0),
      )!;

      expect(score.correctValue, Rational.fromInt(10, 21));
      expect(score.wrongValue, Rational.fromInt(-5, 42));
      // 13·10/21 − 8·5/42 = 130/21 − 20/21 = 110/21 = 5,238095…
      expect(score.exact, Rational.fromInt(110, 21));
      expect(score.scoreText, '5.238');
      expect(score.passed, isTrue);
    });

    test('ej. 2 en el límite: 12 aciertos, 7 fallos y 2 en blanco', () {
      final score = ScoreCalculator.score(
        exam.papers.last.scoring!,
        const ExamTally(correct: 12, wrong: 7, blank: 2),
      )!;

      // (12 − 7/4)·10/21 = 41/4 · 10/21 = 205/42 = 4,880952…
      expect(score.exact, Rational.fromInt(205, 42));
      expect(score.scoreText, '4.881');
      expect(score.passed, isFalse);
      // Netos: 10,25; hacían falta 10,5 (5 · 21/10).
      expect(score.missingNetCorrect, Rational.fromInt(1, 4));
    });
  });

  test('examen real de 2026: el ej. 2 tiene 24 valorables', () async {
    final exam = await plan(
      const ExamSetup(kind: ExamKind.realExam, sourceId: 'zgz-2026-tl'),
    );

    expect(exam.papers.map((p) => p.questionIds.length), [50, 24]);
  });

  test('aleatorio completo: 50 + 25 preguntas oficiales', () async {
    final exam = await plan(const ExamSetup());

    expect(exam.papers.map((p) => p.questionIds.length), [50, 25]);
  });

  test('el cuadernillo de estudio no se ofrece como examen real', () async {
    final sources = ExamPlan.realExamSources(
      await content.outline(packId),
      await content.examRules(packId),
    );

    expect(sources.map((s) => s.id), [
      'zgz-2026-tl',
      'zgz-2024-tl',
      'zgz-2023-le',
    ]);
  });
}
