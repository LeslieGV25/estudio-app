import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/packs.dart';
import '../../../../helpers/review.dart';
import '../../../../helpers/test_database.dart';

/// Simulacro de principio a fin con el pack `completo` y la base de datos
/// real en memoria. El examen `examen-2026` tiene:
/// - ej1 (proporcional, mínimo 5, 3 decimales): e1-01 (correcta b),
///   e1-02 anulada, e1-r1 reserva (correcta b), e1-03 obsoleta.
/// - ej2 (fijo: +1 / −0,33, mínimo 0,5, 2 decimales): e2-01 (correcta b).
void main() {
  const packId = 'test-completo';
  const cal = FixedOffsetCalendar.madridSummer;
  late AppDatabase db;
  late DriftPackContentRepository content;
  late DriftProgressRepository progress;
  late DriftReviewRepository review;
  late StartExam start;
  late SubmitExamPart submit;
  late LoadExamResult load;
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
    load = LoadExamResult(content, progress);
  });
  tearDown(() => db.close());

  Future<ExamPlan> plan({String? exerciseId}) async => ExamPlan.build(
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

  ExamSessionConfig configOf(StudySession s) =>
      ExamSessionConfig.fromJson(s.config);

  Future<StudySession> reload(String id) async =>
      (await progress.findSession(id))!;

  /// Marca opciones en el borrador, como haría la pantalla.
  Future<void> mark(StudySession s, Map<String, String> choices) async {
    var config = configOf(await reload(s.id));
    for (final MapEntry(:key, :value) in choices.entries) {
      config = config.withChoice(key, value).withTimeSpent(key, 1000);
    }
    await progress.updateSessionConfig(s.id, config.toJson());
  }

  test(
    'empezar crea la sesión del primer ejercicio con el resto pendiente',
    () async {
      final session = (await start(packId, await plan()))!;

      expect(session.mode, SessionMode.exam);
      final config = configOf(session);
      expect(config.paper.questionIds, ['e1-01', 'e1-r1']);
      expect(config.paper.replacements, {'e1-02': 'e1-r1'});
      expect(config.pending.map((p) => p.exerciseId), ['ej2']);
    },
  );

  test('un plan vacío no crea sesión', () async {
    final empty = ExamPlan.build(
      questions: const [],
      outline: await content.outline(packId),
      rules: await content.examRules(packId),
      setup: const ExamSetup(),
      random: Random(1),
    );

    expect(await start(packId, empty), isNull);
  });

  group('entregar', () {
    test('el borrador pasa a respuestas: lo no marcado, en blanco', () async {
      final session = (await start(packId, await plan()))!;
      await mark(session, {'e1-01': 'b'});

      await submit(session.id);

      final answers = await progress.sessionAnswers(session.id);
      expect(
        [for (final a in answers) (a.questionId, a.chosen, a.isCorrect)],
        [('e1-01', 'b', true), ('e1-r1', null, false)],
      );
      expect(answers.first.timeMs, 1000);
    });

    test('guarda la nota y vacía el borrador', () async {
      final session = (await start(packId, await plan()))!;
      await mark(session, {'e1-01': 'b'});

      await submit(session.id);

      // 2 valorables: acierto 10/2 = 5. 1 acierto + 1 en blanco = 5,000.
      final done = await reload(session.id);
      expect(done.isFinished, isTrue);
      expect(done.score, '5.000');
      expect(configOf(done).choices, isEmpty);
      expect(configOf(done).timeMs, isEmpty);
      expect(configOf(done).nextSessionId, isNotNull);
    });

    test('el último ejercicio no apunta a ningún siguiente', () async {
      final session = (await start(packId, await plan(exerciseId: 'ej2')))!;

      await submit(session.id);

      expect(configOf(await reload(session.id)).nextSessionId, isNull);
    });

    test('no se puede entregar dos veces', () async {
      final session = (await start(packId, await plan()))!;
      await submit(session.id);

      expect(() => submit(session.id), throwsStateError);
    });

    test('las falladas y en blanco entran en el repaso', () async {
      final session = (await start(packId, await plan()))!;
      await mark(session, {'e1-01': 'a'});

      await submit(session.id);

      expect((await review.watchStates(packId).first).keys.toSet(), {
        'e1-01',
        'e1-r1',
      });
    });
  });

  group('siguiente ejercicio', () {
    test('se crea al empezarlo, con el id apuntado, y solo una vez', () async {
      final first = (await start(packId, await plan()))!;
      await submit(first.id);
      now = now.add(const Duration(minutes: 5));

      final second = (await start.next(await reload(first.id)))!;
      final again = (await start.next(await reload(first.id)))!;

      expect(second.id, configOf(await reload(first.id)).nextSessionId);
      expect(again, second);
      // El temporizador del ej. 2 empieza al empezarlo, no al entregar el 1.
      expect(second.startedAt, now);
      expect(configOf(second).paper.exerciseId, 'ej2');
      expect(configOf(second).pending, isEmpty);
      expect(configOf(second).previousSessionId, first.id);
    });

    test('no hay siguiente si el ejercicio no se ha entregado', () async {
      final first = (await start(packId, await plan()))!;

      expect(await start.next(first), isNull);
    });
  });

  group('resultado', () {
    Future<ExamResult> runBoth({
      required Map<String, String> ej1,
      required Map<String, String> ej2,
    }) async {
      final first = (await start(packId, await plan()))!;
      await mark(first, ej1);
      await submit(first.id);
      final second = (await start.next(await reload(first.id)))!;
      await mark(second, ej2);
      await submit(second.id);
      return (await load(second.id))!;
    }

    test('ej. 1 aprobado: los dos ejercicios se corrigen', () async {
      final result = await runBoth(
        ej1: {'e1-01': 'b', 'e1-r1': 'b'},
        ej2: {'e2-01': 'a'},
      );

      expect(result.parts.map((p) => p.status), [
        ExamPartStatus.graded,
        ExamPartStatus.graded,
      ]);
      expect(result.parts.first.score!.scoreText, '10.000');
      expect(result.parts.first.score!.passed, isTrue);
      // Fijo: un fallo = −0,33.
      expect(result.parts.last.score!.scoreText, '-0.33');
      expect(result.parts.last.score!.passed, isFalse);
    });

    test('ej. 1 suspendido: el ej. 2 sale como «no corregido»', () async {
      final result = await runBoth(
        ej1: {'e1-01': 'a', 'e1-r1': 'a'},
        ej2: {'e2-01': 'b'},
      );

      // 2 fallos: 2 · (−5 · ¼) = −2,5.
      expect(result.parts.first.score!.scoreText, '-2.500');
      expect(result.parts.map((p) => p.status), [
        ExamPartStatus.graded,
        ExamPartStatus.notCorrected,
      ]);
      // Las respuestas del ej. 2 se pueden revisar igual.
      expect(result.parts.last.summary!.correct, 1);
    });

    test('se carga igual desde cualquiera de sus sesiones', () async {
      final first = (await start(packId, await plan()))!;
      await submit(first.id);
      final second = (await start.next(await reload(first.id)))!;

      final fromFirst = (await load(first.id))!;
      final fromSecond = (await load(second.id))!;

      expect(fromFirst.firstSession.id, first.id);
      expect(fromSecond.firstSession.id, first.id);
      expect(fromSecond.parts.map((p) => p.status), [
        ExamPartStatus.graded,
        ExamPartStatus.inProgress,
      ]);
    });

    test('terminar tras el ej. 1: el ej. 2 queda «no realizado»', () async {
      final first = (await start(packId, await plan()))!;
      await submit(first.id);

      final result = (await load(first.id))!;

      expect(result.parts.map((p) => (p.paper.exerciseId, p.status)), [
        ('ej1', ExamPartStatus.graded),
        ('ej2', ExamPartStatus.notTaken),
      ]);
    });

    test('si después se anula una pregunta, deja de ser valorable', () async {
      final first = (await start(packId, await plan(exerciseId: 'ej1')))!;
      await mark(first, {'e1-01': 'b', 'e1-r1': 'a'});
      await submit(first.id);
      // Nota al entregar: 2 valorables, 1 acierto y 1 fallo:
      // 5 − 5·¼ = 3,750.
      expect((await reload(first.id)).score, '3.750');

      // El tribunal anula después la reserva que se falló.
      await (db.update(
        db.questions,
      )..where((q) => q.packId.equals(packId) & q.id.equals('e1-r1'))).write(
        const QuestionsCompanion(voided: Value(true), correctKey: Value(null)),
      );

      final part = (await load(first.id))!.parts.single;
      // Queda 1 valorable, acertada: 10,000. La guardada no se toca.
      expect(part.summary!.notCounted, 1);
      expect(part.score!.scoreText, '10.000');
      expect((await reload(first.id)).score, '3.750');
    });

    test('una sesión que no existe no tiene resultado', () async {
      expect(await load('no-existe'), isNull);
    });
  });
}
