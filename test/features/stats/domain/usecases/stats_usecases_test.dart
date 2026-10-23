import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/exam/domain/exam_plan.dart';
import 'package:estudio_app/features/exam/domain/exam_session_config.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/exam/domain/usecases/load_exam_result.dart';
import 'package:estudio_app/features/exam/domain/usecases/start_exam.dart';
import 'package:estudio_app/features/exam/domain/usecases/submit_exam_part.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/progress/domain/entities/study_session.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/domain/usecases/sync_review_state.dart';
import 'package:estudio_app/features/stats/domain/stats_filter.dart';
import 'package:estudio_app/features/stats/domain/usecases/load_exam_history.dart';
import 'package:estudio_app/features/stats/domain/usecases/load_pack_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/packs.dart';
import '../../../../helpers/review.dart';
import '../../../../helpers/test_database.dart';

/// Con el pack `completo` y la base de datos real en memoria. El examen
/// `examen-2026` tiene:
/// - ej1 (proporcional, mínimo 5): e1-01 (correcta b), e1-02 anulada,
///   e1-r1 reserva (correcta b), e1-03 obsoleta.
/// - ej2 (fijo: +1 / −0,33, mínimo 0,5): e2-01 (correcta b).
void main() {
  const packId = 'test-completo';
  const cal = FixedOffsetCalendar.madridSummer;
  late AppDatabase db;
  late DriftPackContentRepository content;
  late DriftProgressRepository progress;
  late DriftReviewRepository review;
  late StartExam start;
  late SubmitExamPart submit;
  late DateTime now;

  setUp(() async {
    db = newTestDatabase();
    now = cal.at(2026, 10, 18, 9);
    await DriftPackRepository(db).save(loadPack(completoPath));
    content = DriftPackContentRepository(db);
    progress = DriftProgressRepository(db, clock: () => now);
    review = DriftReviewRepository(db, clock: () => now);
    start = StartExam(progress);
    submit = SubmitExamPart(
      content,
      progress,
      SyncReviewState(progress, review, cal),
    );
  });
  tearDown(() => db.close());

  Future<StudySession> startExam({String? exerciseId}) async {
    final plan = ExamPlan.build(
      questions: await content.questions(packId),
      outline: await content.outline(packId),
      rules: await content.examRules(packId),
      setup: ExamSetup(
        kind: ExamKind.realExam,
        sourceId: 'examen-2026',
        exerciseId: exerciseId,
      ),
      random: Random(1),
    );
    return (await start(packId, plan))!;
  }

  Future<StudySession> reload(String id) async =>
      (await progress.findSession(id))!;

  /// Marca [choices] y entrega.
  Future<void> answer(StudySession s, Map<String, String> choices) async {
    var config = ExamSessionConfig.fromJson((await reload(s.id)).config);
    for (final MapEntry(:key, :value) in choices.entries) {
      config = config.withChoice(key, value).withTimeSpent(key, 1000);
    }
    await progress.updateSessionConfig(s.id, config.toJson());
    await submit(s.id);
  }

  /// Simulacro completo: ej1 y, a continuación, ej2.
  Future<void> fullExam(
    Map<String, String> ej1,
    Map<String, String> ej2,
  ) async {
    final first = await startExam();
    await answer(first, ej1);
    now = now.add(const Duration(minutes: 55));
    await answer((await start.next(await reload(first.id)))!, ej2);
  }

  group('LoadExamHistory', () {
    late LoadExamHistory load;

    setUp(() {
      load = LoadExamHistory(
        content,
        progress,
        LoadExamResult(content, progress),
      );
    });

    test('sin simulacros, historial vacío', () async {
      final history = await load(packId);

      expect(history.entries, isEmpty);
      expect(history.series, isEmpty);
    });

    test(
      'una entrada por simulacro, del más reciente al más antiguo',
      () async {
        // 1.º: ej1 aprobado (10) y ej2 con un acierto (1).
        await fullExam({'e1-01': 'b', 'e1-r1': 'b'}, {'e2-01': 'b'});
        now = cal.at(2026, 10, 20, 9);
        // 2.º: ej1 suspendido (−2,5): el ej2 queda «no corregido».
        await fullExam({'e1-01': 'a', 'e1-r1': 'a'}, {'e2-01': 'b'});
        now = cal.at(2026, 10, 22, 9);
        // 3.º: solo el ej1, sin entregar.
        await startExam(exerciseId: 'ej1');

        final history = await load(packId);

        expect(history.entries, hasLength(3));
        expect(
          [for (final e in history.entries) e.startedAt],
          [
            cal.at(2026, 10, 22, 9),
            cal.at(2026, 10, 20, 9),
            cal.at(2026, 10, 18, 9),
          ],
        );
        final [latest, failed, passed] = history.entries;
        expect(latest.isFull, isFalse);
        expect(latest.inProgress, isTrue);
        expect(failed.isFull, isTrue);
        expect(failed.result.parts.last.status, ExamPartStatus.notCorrected);
        expect(passed.sourceName, isNotNull);
      },
    );

    test('series por ejercicio, solo con lo corregido', () async {
      await fullExam({'e1-01': 'b', 'e1-r1': 'b'}, {'e2-01': 'b'});
      now = cal.at(2026, 10, 20, 9);
      await fullExam({'e1-01': 'a', 'e1-r1': 'a'}, {'e2-01': 'b'});
      now = cal.at(2026, 10, 22, 9);
      await startExam(exerciseId: 'ej1');

      final history = await load(packId);

      expect([for (final s in history.series) s.exerciseId], ['ej1', 'ej2']);
      final [ej1, ej2] = history.series;
      expect(
        [for (final p in ej1.points) (p.score.toString(), p.passed)],
        [('10', true), ('-2.5', false)],
      );
      expect(ej1.passMark, Decimal.fromInt(5));
      // El ej2 del segundo simulacro no se corrigió: no tiene nota.
      expect([for (final p in ej2.points) p.score], [Decimal.one]);
      expect(ej2.passMark, Decimal.parse('0.5'));
    });
  });

  group('LoadPackStats', () {
    late LoadPackStats load;

    setUp(() => load = LoadPackStats(content, progress, review, cal));

    Future<void> practice(String questionId, {required bool correct}) async {
      final session = await progress.startSession(
        packId: packId,
        mode: SessionMode.practice,
        config: const {},
      );
      await progress.recordAnswer(
        sessionId: session.id,
        questionId: questionId,
        chosen: correct ? 'b' : 'a',
        isCorrect: correct,
        timeMs: 2000,
      );
    }

    test('junta práctica y simulacro, y filtra por modo', () async {
      await practice('e1-01', correct: false);
      await practice('e2-01', correct: true);
      // Simulacro de un ejercicio: e1-01 bien, e1-r1 en blanco.
      await answer(await startExam(exerciseId: 'ej1'), {'e1-01': 'b'});

      final all = await load(packId, filter: const StatsFilter(), now: now);
      final onlyPractice = await load(
        packId,
        filter: const StatsFilter(modes: {SessionMode.practice}),
        now: now,
      );

      expect((all.tally.correct, all.tally.wrong, all.tally.blank), (2, 1, 1));
      expect((onlyPractice.tally.correct, onlyPractice.tally.wrong), (1, 1));
      expect(onlyPractice.coverage.seen, 2);
      expect(all.coverage.seen, 3);
    });
  });
}
