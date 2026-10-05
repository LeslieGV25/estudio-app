import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/user_tables.dart';
import '../../../core/utils/ids.dart';
import '../domain/review_repository.dart';
import '../domain/review_state.dart';

/// Implementa [ReviewRepository] sobre la tabla `review_state`.
///
/// A diferencia de `answers`, aquí sí se actualiza y se borra: es una caché
/// derivable, no un evento.
class DriftReviewRepository implements ReviewRepository {
  DriftReviewRepository(this._db, {this._clock = nowUtc});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<void> saveStates(String packId, Map<String, ReviewState?> states) =>
      _db.transaction(() async {
        final removed = [
          for (final MapEntry(:key, :value) in states.entries)
            if (value == null) key,
        ];
        if (removed.isNotEmpty) {
          await (_db.delete(_db.reviewStates)
                ..where((r) => _ofPack(r, packId) & r.questionId.isIn(removed)))
              .go();
        }
        await _upsert(packId, {
          for (final MapEntry(:key, :value) in states.entries)
            if (value != null) key: value,
        });
      });

  @override
  Future<void> replaceAll(String packId, Map<String, ReviewState> states) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.reviewStates,
        )..where((r) => _ofPack(r, packId))).go();
        await _upsert(packId, states);
      });

  @override
  Stream<Map<String, ReviewState>> watchStates(String packId) =>
      (_db.select(
        _db.reviewStates,
      )..where((r) => _ofPack(r, packId))).watch().map(
        (rows) => {
          for (final row in rows)
            row.questionId: ReviewState(
              box: row.box,
              correctStreak: row.correctStreak,
              nextDue: row.nextDue,
            ),
        },
      );

  Expression<bool> _ofPack($ReviewStatesTable r, String packId) =>
      r.userId.equals(localUserId) & r.packId.equals(packId);

  Future<void> _upsert(String packId, Map<String, ReviewState> states) async {
    if (states.isEmpty) return;
    final now = _clock();
    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(_db.reviewStates, [
        for (final MapEntry(key: questionId, value: state) in states.entries)
          ReviewStatesCompanion.insert(
            packId: packId,
            questionId: questionId,
            box: state.box,
            correctStreak: Value(state.correctStreak),
            nextDue: state.nextDue,
            updatedAt: Value(now),
          ),
      ]);
    });
  }
}
