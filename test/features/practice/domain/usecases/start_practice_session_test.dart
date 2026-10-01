import 'dart:math';

import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/practice/domain/practice_filter.dart';
import 'package:estudio_app/features/practice/domain/practice_session_config.dart';
import 'package:estudio_app/features/practice/domain/usecases/start_practice_session.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/packs.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository progress;
  late StartPracticeSession start;

  const packId = 'test-completo';

  setUp(() async {
    db = newTestDatabase();
    await DriftPackRepository(db).save(loadPack(completoPath));
    progress = DriftProgressRepository(db);
    start = StartPracticeSession(
      DriftPackContentRepository(db),
      progress,
      random: Random(42),
    );
  });
  tearDown(() => db.close());

  PracticeStarted started(PracticeStart result) {
    expect(result, isA<PracticeStarted>());
    return result as PracticeStarted;
  }

  test('crea una sesión de práctica con las preguntas que cumplen', () async {
    final result = started(await start(packId, const PracticeFilter()));

    // Quedan fuera la anulada (e1-02, siempre) y la obsoleta (e1-03, por
    // defecto).
    expect(
      result.config.questionIds,
      unorderedEquals(['e1-01', 'e1-r1', 'e2-01', 'est-01']),
    );
    expect(result.session.mode, SessionMode.practice);
    expect(result.session.packId, packId);
  });

  test('guarda filtro y preguntas en la configuración de la sesión', () async {
    const filter = PracticeFilter(topicIds: {3}, questionCount: 10);

    final result = started(await start(packId, filter));

    final saved = await progress.findSession(result.session.id);
    final config = PracticeSessionConfig.fromJson(saved!.config);
    expect(config, result.config);
    expect(config.filter, filter);
    expect(config.questionIds, unorderedEquals(['e2-01', 'est-01']));
  });

  test('respeta el nº de preguntas pedido', () async {
    final result = started(
      await start(packId, const PracticeFilter(questionCount: 2)),
    );

    expect(result.config.questionIds, hasLength(2));
  });

  test('si nada cumple el filtro no crea sesión', () async {
    final result = await start(
      packId,
      const PracticeFilter(onlyOfficial: true, sourceIds: {'estudio'}),
    );

    expect(result, isA<NoQuestionsMatch>());
    expect(await db.select(db.sessions).get(), isEmpty);
  });

  group('retry («repasar estas»)', () {
    test('crea una sesión con esas preguntas en el mismo orden', () async {
      final result = started(
        await start.retry(packId, [
          'est-01',
          'e1-01',
        ], fromSessionId: 'anterior'),
      );

      expect(result.config.questionIds, ['est-01', 'e1-01']);
      expect(result.config.retryOf, 'anterior');
      expect(result.config.filter, isNull);
    });

    test('omite las que ya no existen en el pack', () async {
      final result = started(
        await start.retry(packId, [
          'borrada',
          'e1-01',
        ], fromSessionId: 'anterior'),
      );

      expect(result.config.questionIds, ['e1-01']);
    });

    test('omite las anuladas, aunque tengan provisional', () async {
      // e1-02 ya viene anulada; una versión nueva del pack anula además
      // e1-01, que la usuaria pudo haber fallado antes.
      final pack = loadPack(completoPath);
      await DriftPackRepository(db).save(
        pack.copyWith(
          questions: [
            for (final q in pack.questions)
              q.id == 'e1-01' ? q.copyWith(voided: true, correctKey: null) : q,
          ],
        ),
      );

      final result = started(
        await start.retry(packId, [
          'e1-01',
          'e1-02',
          'est-01',
        ], fromSessionId: 'anterior'),
      );

      expect(result.config.questionIds, ['est-01']);
    });

    test('si no queda ninguna no crea sesión', () async {
      final result = await start.retry(packId, [
        'borrada',
      ], fromSessionId: 'anterior');

      expect(result, isA<NoQuestionsMatch>());
    });
  });
}
