import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:estudio_app/features/review/domain/usecases/sync_review_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/review.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  late AppDatabase db;
  late DriftProgressRepository progress;
  late DriftReviewRepository review;
  late SyncReviewState sync;
  late DateTime now;

  setUp(() {
    db = newTestDatabase();
    now = cal.at(2026, 10, 5, 10);
    progress = DriftProgressRepository(db, clock: () => now);
    review = DriftReviewRepository(db, clock: () => now);
    sync = SyncReviewState(progress, review, cal);
  });
  tearDown(() => db.close());

  Future<String> start(SessionMode mode, {String packId = 'pack'}) async =>
      (await progress.startSession(
        packId: packId,
        mode: mode,
        config: const {},
      )).id;

  Future<void> answer(String sessionId, String questionId, bool correct) =>
      progress.recordAnswer(
        sessionId: sessionId,
        questionId: questionId,
        chosen: correct ? 'a' : 'b',
        isCorrect: correct,
        timeMs: 1,
      );

  Future<Map<String, ReviewState>> states([String packId = 'pack']) =>
      review.watchStates(packId).first;

  final failedToday = ReviewState(
    box: 0,
    correctStreak: 0,
    nextDue: cal.at(2026, 10, 5),
  );

  group('call', () {
    test('una pregunta fallada entra en la caché', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', false);

      await sync('pack', ['q1']);

      expect(await states(), {'q1': failedToday});
    });

    test('solo recalcula las preguntas pedidas', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', false);
      await answer(s, 'q2', false);

      await sync('pack', ['q2']);

      expect((await states()).keys, ['q2']);
    });

    test('una pregunta acertada sin fallos no entra', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', true);

      await sync('pack', ['q1']);

      expect(await states(), isEmpty);
    });

    test('junta las respuestas de práctica y de repaso', () async {
      final practice = await start(SessionMode.practice);
      await answer(practice, 'q1', false);
      now = cal.at(2026, 10, 6, 9);
      final rev = await start(SessionMode.review);
      await answer(rev, 'q1', true);

      await sync('pack', ['q1']);

      expect(
        (await states())['q1'],
        ReviewState(box: 1, correctStreak: 1, nextDue: cal.at(2026, 10, 7)),
      );
    });

    test('las respuestas de simulacro no cuentan (Fase 4)', () async {
      final exam = await start(SessionMode.exam);
      await answer(exam, 'q1', false);

      await sync('pack', ['q1']);

      expect(await states(), isEmpty);
    });

    test('es idempotente: sincronizar dos veces da lo mismo', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', false);

      await sync('pack', ['q1']);
      await sync('pack', ['q1']);

      expect(await states(), {'q1': failedToday});
    });

    test('corrige una caché que no cuadra con las respuestas', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', false);
      await review.saveStates('pack', {
        'q1': ReviewState(box: 4, correctStreak: 9, nextDue: now),
        'q2': failedToday, // sin respuestas: no debería estar
      });

      await sync('pack', ['q1', 'q2']);

      expect(await states(), {'q1': failedToday});
    });
  });

  group('rebuild', () {
    test('rehace la caché entera del pack desde las respuestas', () async {
      final s = await start(SessionMode.practice);
      await answer(s, 'q1', false);
      await answer(s, 'q2', true);
      await answer(s, 'q3', false);
      await review.saveStates('pack', {'viejo': failedToday});

      await sync.rebuild('pack');

      expect(await states(), {'q1': failedToday, 'q3': failedToday});
    });

    test('no toca otros packs', () async {
      final other = await start(SessionMode.practice, packId: 'otro');
      await answer(other, 'q1', false);
      await sync('otro', ['q1']);

      await sync.rebuild('pack');

      expect(await states('otro'), {'q1': failedToday});
    });
  });
}
