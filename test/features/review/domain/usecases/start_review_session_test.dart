import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/practice/domain/practice_session_config.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:estudio_app/features/review/domain/usecases/start_review_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/packs.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const packId = 'test-completo';
  late AppDatabase db;
  late DriftProgressRepository progress;
  late DriftReviewRepository review;
  late StartReviewSession start;
  final now = DateTime.utc(2026, 10, 5, 10);

  setUp(() async {
    db = newTestDatabase();
    await DriftPackRepository(db).save(loadPack(completoPath));
    progress = DriftProgressRepository(db, clock: () => now);
    review = DriftReviewRepository(db, clock: () => now);
    start = StartReviewSession(
      DriftPackContentRepository(db),
      review,
      progress,
      () => now,
    );
  });
  tearDown(() => db.close());

  ReviewState dueAt(DateTime when, {int box = 0}) =>
      ReviewState(box: box, correctStreak: 0, nextDue: when);

  test('crea una sesión de repaso con las pendientes en orden', () async {
    await review.saveStates(packId, {
      'e1-r1': dueAt(now.subtract(const Duration(hours: 1))),
      'e1-01': dueAt(now.subtract(const Duration(days: 2)), box: 2),
      'e2-01': dueAt(now.add(const Duration(days: 1))), // mañana
      'e1-02': dueAt(now.subtract(const Duration(days: 9))), // anulada
    });

    final session = await start(packId);

    expect(session, isNotNull);
    expect(session!.mode, SessionMode.review);
    expect(session.packId, packId);
    expect(PracticeSessionConfig.fromJson(session.config).questionIds, [
      'e1-01',
      'e1-r1',
    ]);
  });

  test('respeta el límite', () async {
    await review.saveStates(packId, {
      'e1-01': dueAt(now.subtract(const Duration(days: 2))),
      'e1-r1': dueAt(now.subtract(const Duration(days: 1))),
    });

    final session = await start(packId, limit: 1);

    expect(PracticeSessionConfig.fromJson(session!.config).questionIds, [
      'e1-01',
    ]);
  });

  test('sin pendientes no crea sesión', () async {
    await review.saveStates(packId, {
      'e1-01': dueAt(now.add(const Duration(days: 1))),
    });

    expect(await start(packId), isNull);
    expect(await db.select(db.sessions).get(), isEmpty);
  });
}
