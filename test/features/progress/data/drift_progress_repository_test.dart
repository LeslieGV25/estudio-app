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
}
