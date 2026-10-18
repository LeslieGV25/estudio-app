import 'dart:math';

import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/db/app_database_provider.dart';
import 'package:estudio_app/core/utils/clock_provider.dart';
import 'package:estudio_app/features/exam/domain/exam_plan.dart';
import 'package:estudio_app/features/exam/domain/exam_session_config.dart';
import 'package:estudio_app/features/exam/domain/exam_setup.dart';
import 'package:estudio_app/features/exam/domain/usecases/start_exam.dart';
import 'package:estudio_app/features/exam/presentation/exam_session_controller.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/review/data/review_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/review.dart';
import '../../../helpers/test_database.dart';

/// Ej. 1 del examen real del pack `completo`: e1-01 (correcta b) y la
/// reserva e1-r1 (correcta b), 55 minutos.
void main() {
  const packId = 'test-completo';
  late AppDatabase db;
  late DriftProgressRepository progress;
  late DateTime now;
  late String sessionId;

  ProviderContainer newContainer() {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
        reviewCalendarProvider.overrideWithValue(
          FixedOffsetCalendar.madridSummer,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() async {
    db = newTestDatabase();
    now = DateTime.utc(2026, 10, 18, 8);
    await DriftPackRepository(db).save(loadPack(completoPath));
    progress = DriftProgressRepository(db, clock: () => now);
    final content = DriftPackContentRepository(db);
    final plan = ExamPlan.build(
      questions: await content.questions(packId),
      outline: await content.outline(packId),
      rules: await content.examRules(packId),
      setup: const ExamSetup(
        kind: ExamKind.realExam,
        sourceId: 'examen-2026',
        exerciseId: 'ej1',
      ),
      random: Random(1),
    );
    sessionId = (await StartExam(progress)(packId, plan))!.id;
  });
  tearDown(() => db.close());

  Future<ExamSessionState> load(ProviderContainer container) async {
    final provider = examSessionControllerProvider(sessionId);
    container.listen(provider, (_, _) {});
    final state = await container.read(provider.future);
    return state!;
  }

  ExamSessionController controller(ProviderContainer container) =>
      container.read(examSessionControllerProvider(sessionId).notifier);

  Future<ExamSessionConfig> savedConfig() async => ExamSessionConfig.fromJson(
    (await progress.findSession(sessionId))!.config,
  );

  test('empieza por la primera, sin nada marcado', () async {
    final state = await load(newContainer());

    expect(state.current.id, 'e1-01');
    expect(state.currentChoice, isNull);
    expect(state.deadline, now.add(const Duration(minutes: 55)));
  });

  test('marcar y cambiar se guarda en la base de datos al momento', () async {
    final container = newContainer();
    await load(container);

    controller(container).choose('a');
    controller(container).choose('b');
    await pumpEventQueue();

    expect((await savedConfig()).choices, {'e1-01': 'b'});
  });

  test('al recargar sigue en la misma pregunta con lo marcado', () async {
    final first = newContainer();
    await load(first);
    controller(first).choose('b');
    controller(first).goTo(1);
    controller(first).choose('c');
    await pumpEventQueue();
    first.dispose();

    final reloaded = await load(newContainer());

    expect(reloaded.current.id, 'e1-r1');
    expect(reloaded.currentChoice, 'c');
    expect(reloaded.config.choices, {'e1-01': 'b', 'e1-r1': 'c'});
  });

  test('suma el tiempo de cada pregunta entre visitas', () async {
    final container = newContainer();
    await load(container);

    now = now.add(const Duration(seconds: 10));
    controller(container).goTo(1);
    now = now.add(const Duration(seconds: 4));
    controller(container).goTo(0);
    now = now.add(const Duration(seconds: 5));
    controller(container).goTo(1);
    await pumpEventQueue();

    expect((await savedConfig()).timeMs, {'e1-01': 15000, 'e1-r1': 4000});
  });

  test('entregar guarda las respuestas y recarga como entregado', () async {
    final container = newContainer();
    await load(container);
    controller(container).choose('b');

    await controller(container).submit();

    final state = container
        .read(examSessionControllerProvider(sessionId))
        .value!;
    expect(state.session.isFinished, isTrue);
    expect(state.session.score, '5.000');
    expect((await progress.sessionAnswers(sessionId)).map((a) => a.chosen), [
      'b',
      null,
    ]);
  });

  test('tras entregar ya no se puede cambiar nada', () async {
    final container = newContainer();
    await load(container);
    await controller(container).submit();

    controller(container).choose('a');
    await pumpEventQueue();

    expect(
      container
          .read(examSessionControllerProvider(sessionId))
          .value!
          .config
          .choices,
      isEmpty,
    );
  });

  test('si se vuelve con el tiempo vencido, se entrega solo', () async {
    final first = newContainer();
    await load(first);
    controller(first).choose('b');
    await pumpEventQueue();
    first.dispose();
    now = now.add(const Duration(minutes: 56));

    final state = await load(newContainer());

    expect(state.session.isFinished, isTrue);
    expect((await progress.sessionAnswers(sessionId)).map((a) => a.chosen), [
      'b',
      null,
    ]);
  });
}
