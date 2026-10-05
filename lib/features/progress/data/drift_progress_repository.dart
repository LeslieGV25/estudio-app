import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/domain/session_mode.dart';
import '../../../core/utils/ids.dart';
import '../domain/entities/answer.dart';
import '../domain/entities/study_session.dart';
import '../domain/progress_repository.dart';

class DriftProgressRepository implements ProgressRepository {
  DriftProgressRepository(this._db, {this._clock = nowUtc});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Future<StudySession> startSession({
    required String packId,
    required SessionMode mode,
    required Map<String, Object?> config,
  }) async {
    final now = _clock();
    final row = await _db
        .into(_db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            packId: packId,
            mode: mode,
            config: config,
            startedAt: now,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return _toSession(row);
  }

  @override
  Future<StudySession?> findSession(String sessionId) async {
    final row = await _sessionById(sessionId).getSingleOrNull();
    return row == null ? null : _toSession(row);
  }

  @override
  Future<void> finishSession(String sessionId, {String? score}) async {
    final now = _clock();
    await (_db.update(_db.sessions)..where(
          (s) =>
              s.id.equals(sessionId) &
              s.finishedAt.isNull() &
              s.deletedAt.isNull(),
        ))
        .write(
          SessionsCompanion(
            finishedAt: Value(now),
            score: Value(score),
            updatedAt: Value(now),
          ),
        );
  }

  @override
  Future<Answer> recordAnswer({
    required String sessionId,
    required String questionId,
    required String? chosen,
    required bool isCorrect,
    required int timeMs,
  }) => _db.transaction(() async {
    final session = await _sessionById(sessionId).getSingleOrNull();
    if (session == null) {
      throw StateError('La sesión $sessionId no existe');
    }
    if (session.finishedAt != null) {
      throw StateError('La sesión $sessionId ya terminó');
    }
    final row = await _db
        .into(_db.answers)
        .insertReturning(
          AnswersCompanion.insert(
            sessionId: sessionId,
            packId: session.packId,
            questionId: questionId,
            chosen: Value(chosen),
            isCorrect: isCorrect,
            timeMs: timeMs,
            answeredAt: Value(_clock()),
          ),
        );
    return _toAnswer(row);
  });

  @override
  Future<List<Answer>> sessionAnswers(String sessionId) async =>
      (await _answersOf(sessionId).get()).map(_toAnswer).toList();

  @override
  Stream<List<Answer>> watchSessionAnswers(String sessionId) =>
      _answersOf(sessionId).watch().map((rows) => rows.map(_toAnswer).toList());

  @override
  Future<List<Answer>> packAnswers(
    String packId, {
    required Set<SessionMode> modes,
    Iterable<String>? questionIds,
  }) async {
    final answers = _db.answers;
    final sessions = _db.sessions;
    var filter =
        answers.packId.equals(packId) &
        sessions.mode.isInValues(modes) &
        sessions.deletedAt.isNull();
    if (questionIds != null) {
      filter = filter & answers.questionId.isIn(questionIds);
    }
    final query =
        _db.select(answers).join([
            innerJoin(sessions, sessions.id.equalsExp(answers.sessionId)),
          ])
          ..where(filter)
          ..orderBy([
            OrderingTerm.asc(answers.answeredAt),
            OrderingTerm.asc(answers.rowId),
          ]);
    final rows = await query.get();
    return [for (final row in rows) _toAnswer(row.readTable(answers))];
  }

  SimpleSelectStatement<$SessionsTable, SessionRow> _sessionById(String id) =>
      _db.select(_db.sessions)
        ..where((s) => s.id.equals(id) & s.deletedAt.isNull());

  // `rowid` desempata respuestas guardadas en el mismo instante.
  SimpleSelectStatement<$AnswersTable, AnswerRow> _answersOf(
    String sessionId,
  ) => _db.select(_db.answers)
    ..where((a) => a.sessionId.equals(sessionId))
    ..orderBy([
      (a) => OrderingTerm.asc(a.answeredAt),
      (a) => OrderingTerm.asc(a.rowId),
    ]);

  StudySession _toSession(SessionRow row) => StudySession(
    id: row.id,
    packId: row.packId,
    mode: row.mode,
    config: row.config,
    startedAt: row.startedAt,
    finishedAt: row.finishedAt,
    score: row.score,
  );

  Answer _toAnswer(AnswerRow row) => Answer(
    id: row.id,
    sessionId: row.sessionId,
    packId: row.packId,
    questionId: row.questionId,
    chosen: row.chosen,
    isCorrect: row.isCorrect,
    timeMs: row.timeMs,
    answeredAt: row.answeredAt,
  );
}
