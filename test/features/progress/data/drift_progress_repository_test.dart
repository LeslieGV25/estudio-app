import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository repo;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = DateTime.utc(2026, 10, 1, 9);
    repo = DriftProgressRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<String> startPractice({String packId = 'pack-a'}) async =>
      (await repo.startSession(
        packId: packId,
        mode: SessionMode.practice,
        config: const {
          'questionIds': ['q1', 'q2'],
        },
      )).id;

  group('sesiones', () {
    test('startSession guarda la sesión con su configuración', () async {
      final id = await startPractice();

      final session = await repo.findSession(id);

      expect(session, isNotNull);
      expect(session!.packId, 'pack-a');
      expect(session.mode, SessionMode.practice);
      expect(session.config, {
        'questionIds': ['q1', 'q2'],
      });
      expect(session.startedAt, now);
      expect(session.isFinished, isFalse);
    });

    test('findSession devuelve null si no existe', () async {
      expect(await repo.findSession('no-existe'), isNull);
    });

    test('findSession ignora las sesiones con borrado lógico', () async {
      final id = await startPractice();
      await (db.update(db.sessions)..where((s) => s.id.equals(id))).write(
        SessionsCompanion(deletedAt: Value(now)),
      );

      expect(await repo.findSession(id), isNull);
    });

    test('finishSession guarda la hora de fin y la nota', () async {
      final id = await startPractice();
      now = now.add(const Duration(minutes: 10));

      await repo.finishSession(id, score: '4.750');

      final session = await repo.findSession(id);
      expect(session!.finishedAt, now);
      expect(session.score, '4.750');
    });

    test('startSession usa el id que se le pasa', () async {
      final session = await repo.startSession(
        id: 'id-fijado',
        packId: 'pack-a',
        mode: SessionMode.exam,
        config: const {},
      );

      expect(session.id, 'id-fijado');
      expect(await repo.findSession('id-fijado'), session);
    });

    test('updateSessionConfig sustituye la configuración', () async {
      final id = await startPractice();
      now = now.add(const Duration(minutes: 1));

      await repo.updateSessionConfig(id, const {
        'choices': {'q1': 'b'},
      });

      final session = await repo.findSession(id);
      expect(session!.config, {
        'choices': {'q1': 'b'},
      });
      final row = await (db.select(
        db.sessions,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(row.updatedAt, now);
    });

    test('updateSessionConfig falla si la sesión ya terminó', () async {
      final id = await startPractice();
      await repo.finishSession(id);

      expect(() => repo.updateSessionConfig(id, const {}), throwsStateError);
      expect(
        () => repo.updateSessionConfig('no-existe', const {}),
        throwsStateError,
      );
    });

    test('terminar dos veces conserva la primera hora de fin', () async {
      final id = await startPractice();
      final firstEnd = now;
      await repo.finishSession(id);
      now = now.add(const Duration(hours: 1));

      await repo.finishSession(id);

      expect((await repo.findSession(id))!.finishedAt, firstEnd);
    });
  });

  group('respuestas', () {
    test('recordAnswer toma el pack de la sesión', () async {
      final id = await startPractice(packId: 'pack-b');

      final answer = await repo.recordAnswer(
        sessionId: id,
        questionId: 'q1',
        chosen: 'b',
        isCorrect: true,
        timeMs: 4200,
      );

      expect(answer.packId, 'pack-b');
      expect(answer.sessionId, id);
      expect(answer.answeredAt, now);
      expect(await repo.sessionAnswers(id), [answer]);
    });

    test('una respuesta en blanco se guarda con chosen null', () async {
      final id = await startPractice();

      final answer = await repo.recordAnswer(
        sessionId: id,
        questionId: 'q1',
        chosen: null,
        isCorrect: false,
        timeMs: 1000,
      );

      expect(answer.isBlank, isTrue);
    });

    test('no se puede responder en una sesión que no existe', () async {
      expect(
        () => repo.recordAnswer(
          sessionId: 'no-existe',
          questionId: 'q1',
          chosen: 'a',
          isCorrect: false,
          timeMs: 1,
        ),
        throwsStateError,
      );
    });

    test('no se puede responder en una sesión terminada', () async {
      final id = await startPractice();
      await repo.finishSession(id);

      expect(
        () => repo.recordAnswer(
          sessionId: id,
          questionId: 'q1',
          chosen: 'a',
          isCorrect: false,
          timeMs: 1,
        ),
        throwsStateError,
      );
    });

    test('sessionAnswers devuelve solo las de la sesión, en orden', () async {
      final id = await startPractice();
      final other = await startPractice();
      for (final q in ['q2', 'q1']) {
        await repo.recordAnswer(
          sessionId: id,
          questionId: q,
          chosen: 'a',
          isCorrect: true,
          timeMs: 1,
        );
      }
      await repo.recordAnswer(
        sessionId: other,
        questionId: 'q9',
        chosen: 'a',
        isCorrect: true,
        timeMs: 1,
      );

      final answers = await repo.sessionAnswers(id);

      // Mismo instante (reloj fijo): el orden de inserción desempata.
      expect(answers.map((a) => a.questionId), ['q2', 'q1']);
    });

    test('watchSessionAnswers emite con cada respuesta nueva', () async {
      final id = await startPractice();

      final emissions = repo.watchSessionAnswers(id).map((a) => a.length);
      expect(emissions, emitsInOrder([0, 1]));

      await pumpEventQueue();
      await repo.recordAnswer(
        sessionId: id,
        questionId: 'q1',
        chosen: 'a',
        isCorrect: true,
        timeMs: 1,
      );
    });
  });

  group('submitSession', () {
    test(
      'guarda las respuestas, la configuración y la nota a la vez',
      () async {
        final id = await startPractice(packId: 'pack-b');
        now = now.add(const Duration(minutes: 30));

        await repo.submitSession(
          id,
          answers: const [
            (questionId: 'q1', chosen: 'a', isCorrect: true, timeMs: 1000),
            (questionId: 'q2', chosen: null, isCorrect: false, timeMs: 0),
          ],
          config: const {'entregada': true},
          score: '5.000',
        );

        final session = await repo.findSession(id);
        expect(session!.finishedAt, now);
        expect(session.score, '5.000');
        expect(session.config, {'entregada': true});
        final answers = await repo.sessionAnswers(id);
        expect(
          [for (final a in answers) (a.questionId, a.chosen, a.packId)],
          [('q1', 'a', 'pack-b'), ('q2', null, 'pack-b')],
        );
        expect(answers.map((a) => a.answeredAt), everyElement(now));
      },
    );

    test('no se puede entregar dos veces', () async {
      final id = await startPractice();
      await repo.submitSession(id, answers: const [], config: const {});

      await expectLater(
        () => repo.submitSession(
          id,
          answers: const [
            (questionId: 'q1', chosen: 'a', isCorrect: true, timeMs: 1),
          ],
          config: const {},
        ),
        throwsStateError,
      );
      expect(await repo.sessionAnswers(id), isEmpty);
    });

    test('si algo falla, no se guarda nada (transacción)', () async {
      final id = await startPractice();
      // Un trigger de prueba hace fallar la segunda respuesta: la primera ya
      // se habría insertado y la sesión aún no estaría cerrada.
      await db.customStatement(
        'CREATE TRIGGER falla_en_q2 BEFORE INSERT ON answers '
        "WHEN NEW.question_id = 'q2' BEGIN SELECT RAISE(ABORT, 'q2'); END",
      );

      await expectLater(
        () => repo.submitSession(
          id,
          answers: const [
            (questionId: 'q1', chosen: 'a', isCorrect: true, timeMs: 1),
            (questionId: 'q2', chosen: 'a', isCorrect: true, timeMs: 1),
          ],
          config: const {'entregada': true},
          score: '1.000',
        ),
        throwsA(anything),
      );

      final session = await repo.findSession(id);
      expect(session!.isFinished, isFalse);
      expect(session.config, isNot(containsPair('entregada', true)));
      expect(await repo.sessionAnswers(id), isEmpty);
    });
  });

  group('packAnswers', () {
    Future<String> start(String packId, SessionMode mode) async =>
        (await repo.startSession(
          packId: packId,
          mode: mode,
          config: const {},
        )).id;

    Future<void> answer(String sessionId, String questionId) =>
        repo.recordAnswer(
          sessionId: sessionId,
          questionId: questionId,
          chosen: 'a',
          isCorrect: true,
          timeMs: 1,
        );

    const studyModes = {SessionMode.practice, SessionMode.review};

    test('devuelve las del pack en los modos pedidos, en orden', () async {
      final practice = await start('pack-a', SessionMode.practice);
      final review = await start('pack-a', SessionMode.review);
      final exam = await start('pack-a', SessionMode.exam);
      final otherPack = await start('pack-b', SessionMode.practice);

      await answer(practice, 'q1');
      now = now.add(const Duration(minutes: 1));
      await answer(exam, 'q1');
      await answer(otherPack, 'q1');
      now = now.add(const Duration(minutes: 1));
      await answer(review, 'q2');

      final answers = await repo.packAnswers('pack-a', modes: studyModes);

      expect(
        [for (final a in answers) (a.sessionId, a.questionId)],
        [(practice, 'q1'), (review, 'q2')],
      );
    });

    test('filtra por preguntas', () async {
      final id = await start('pack-a', SessionMode.practice);
      for (final q in ['q1', 'q2', 'q3']) {
        await answer(id, q);
      }

      final answers = await repo.packAnswers(
        'pack-a',
        modes: studyModes,
        questionIds: ['q3', 'q1'],
      );

      // Mismo instante: desempata el orden de inserción.
      expect(answers.map((a) => a.questionId), ['q1', 'q3']);
    });

    test('ignora las respuestas de sesiones borradas', () async {
      final kept = await start('pack-a', SessionMode.practice);
      final deleted = await start('pack-a', SessionMode.practice);
      await answer(kept, 'q1');
      await answer(deleted, 'q2');
      await (db.update(db.sessions)..where((s) => s.id.equals(deleted))).write(
        SessionsCompanion(deletedAt: Value(now)),
      );

      final answers = await repo.packAnswers('pack-a', modes: studyModes);

      expect(answers.map((a) => a.questionId), ['q1']);
    });
  });
}
