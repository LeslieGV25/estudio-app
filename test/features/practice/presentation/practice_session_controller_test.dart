import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/practice/domain/practice_session_config.dart';
import 'package:estudio_app/features/practice/presentation/practice_session_controller.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DriftProgressRepository progress;
  late DateTime now;

  const packId = 'test-completo';

  setUp(() async {
    db = newTestDatabase();
    now = DateTime.utc(2026, 10, 1, 9);
    await DriftPackRepository(db).save(loadPack(completoPath));
    progress = DriftProgressRepository(db);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> newSession(List<String> ids) async =>
      (await progress.startSession(
        packId: packId,
        mode: SessionMode.practice,
        config: PracticeSessionConfig(questionIds: ids).toJson(),
      )).id;

  Future<PracticeSessionState> load(String sessionId) async {
    final provider = practiceSessionControllerProvider(sessionId);
    // Mantiene vivo el provider (autoDispose) mientras dura el test.
    container.listen(provider, (_, _) {});
    final state = await container.read(provider.future);
    return state!;
  }

  PracticeSessionController controller(String sessionId) =>
      container.read(practiceSessionControllerProvider(sessionId).notifier);

  test('empieza por la primera pregunta', () async {
    final id = await newSession(['est-01', 'e1-01']);

    final state = await load(id);

    expect(state.current.id, 'est-01');
    expect(state.currentAnswer, isNull);
  });

  test('al reanudar sigue por la primera sin responder', () async {
    final id = await newSession(['est-01', 'e1-01', 'e1-r1']);
    await progress.recordAnswer(
      sessionId: id,
      questionId: 'est-01',
      chosen: 'b',
      isCorrect: true,
      timeMs: 1,
    );

    final state = await load(id);

    expect(state.index, 1);
    expect(state.current.id, 'e1-01');
    expect(state.answers.keys, ['est-01']);
  });

  test(
    'si estaban todas respondidas, muestra la última con su feedback',
    () async {
      final id = await newSession(['est-01']);
      await progress.recordAnswer(
        sessionId: id,
        questionId: 'est-01',
        chosen: 'a',
        isCorrect: false,
        timeMs: 1,
      );

      final state = await load(id);

      expect(state.current.id, 'est-01');
      expect(state.currentAnswer, isNotNull);
      expect(state.nextIndex, isNull);
    },
  );

  test('salta las preguntas que el pack anuló después', () async {
    // e1-02 está anulada en el pack (p. ej. tras una actualización).
    final id = await newSession(['e1-02', 'est-01']);

    final state = await load(id);

    expect(state.questions.map((q) => q.id), ['est-01']);
  });

  test('responder guarda el tiempo desde que se mostró la pregunta', () async {
    final id = await newSession(['est-01', 'e1-01']);
    await load(id);
    now = now.add(const Duration(seconds: 8));

    await controller(id).answer('b');

    final state = container
        .read(practiceSessionControllerProvider(id))
        .requireValue!;
    expect(state.currentAnswer!.isCorrect, isTrue);
    expect(state.currentAnswer!.timeMs, 8000);
  });

  test(
    'un segundo toque en la misma pregunta no guarda otra respuesta',
    () async {
      final id = await newSession(['est-01']);
      await load(id);

      await controller(id).answer('b');
      await controller(id).answer('a');

      expect(await progress.sessionAnswers(id), hasLength(1));
    },
  );

  test('next avanza y, al acabar, termina la sesión', () async {
    final id = await newSession(['est-01', 'e1-01']);
    await load(id);

    await controller(id).answer('b');
    expect(await controller(id).next(), isFalse);
    await controller(id).answer('b');
    expect(await controller(id).next(), isTrue);

    expect((await progress.findSession(id))!.isFinished, isTrue);
  });

  test('una sesión que no existe da null', () async {
    final provider = practiceSessionControllerProvider('no-existe');
    container.listen(provider, (_, _) {});

    expect(await container.read(provider.future), isNull);
  });
}
