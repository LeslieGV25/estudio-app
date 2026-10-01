import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../domain/entities/pack_document.dart';
import '../domain/entities/pack_outline.dart';
import '../domain/entities/study_question.dart';
import '../domain/repositories/pack_content_repository.dart';

class DriftPackContentRepository implements PackContentRepository {
  DriftPackContentRepository(this._db);

  final AppDatabase _db;

  @override
  Future<PackOutline> outline(String packId) async {
    final blocks =
        await (_db.select(_db.blocks)
              ..where((b) => b.packId.equals(packId))
              ..orderBy([(b) => OrderingTerm.asc(b.id)]))
            .get();
    final topics =
        await (_db.select(_db.topics)
              ..where((t) => t.packId.equals(packId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final sources =
        await (_db.select(_db.sources)
              ..where((s) => s.packId.equals(packId))
              ..orderBy([(s) => OrderingTerm.asc(s.position)]))
            .get();
    final exercises =
        await (_db.select(_db.sourceExercises)
              ..where((e) => e.packId.equals(packId))
              ..orderBy([(e) => OrderingTerm.asc(e.position)]))
            .get();

    return PackOutline(
      blocks: [for (final b in blocks) Block(id: b.id, name: b.name)],
      topics: [
        for (final t in topics)
          Topic(id: t.id, blockId: t.blockId, title: t.title),
      ],
      sources: [
        for (final s in sources)
          Source(
            id: s.id,
            type: s.type,
            name: s.name,
            isOfficial: s.isOfficial,
            date: s.date,
            call: s.call,
            shift: s.shift,
            answersOrigin: s.answersOrigin,
            exercises: [
              for (final e in exercises.where((e) => e.sourceId == s.id))
                SourceExercise(
                  id: e.id,
                  name: e.name,
                  optionCount: e.optionCount,
                  examExerciseId: e.examExerciseId,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Future<List<StudyQuestion>> questions(String packId) async =>
      (await _questionsOf(packId).get()).map(_toEntity).toList();

  @override
  Future<List<StudyQuestion>> questionsByIds(
    String packId,
    List<String> ids,
  ) async {
    final query = _questionsOf(packId)..where(_db.questions.id.isIn(ids));
    final byId = {
      for (final row in await query.get())
        row.readTable(_db.questions).id: _toEntity(row),
    };
    return [for (final id in ids) ?byId[id]];
  }

  /// Preguntas del pack con su fuente, su tema y (si lo tiene) su contexto.
  JoinedSelectStatement<HasResultSet, dynamic> _questionsOf(String packId) {
    final q = _db.questions;
    final s = _db.sources;
    final t = _db.topics;
    final c = _db.questionContexts;
    // Los ids solo son únicos dentro de su pack: cada join compara también
    // pack_id.
    return _db.select(q).join([
        innerJoin(s, s.packId.equalsExp(q.packId) & s.id.equalsExp(q.sourceId)),
        innerJoin(t, t.packId.equalsExp(q.packId) & t.id.equalsExp(q.topicId)),
        leftOuterJoin(
          c,
          c.packId.equalsExp(q.packId) & c.id.equalsExp(q.contextId),
        ),
      ])
      ..where(q.packId.equals(packId))
      ..orderBy([OrderingTerm.asc(q.position)]);
  }

  StudyQuestion _toEntity(TypedResult row) {
    final q = row.readTable(_db.questions);
    final source = row.readTable(_db.sources);
    final topic = row.readTable(_db.topics);
    final context = row.readTableOrNull(_db.questionContexts);

    return StudyQuestion(
      question: Question(
        id: q.id,
        sourceId: q.sourceId,
        exerciseId: q.exerciseId,
        number: q.number,
        topicId: q.topicId,
        contextId: q.contextId,
        statement: q.statement,
        options: q.options,
        correctKey: q.correctKey,
        isReserve: q.isReserve,
        voided: q.voided,
        provisionalKey: q.provisionalKey,
        obsolete: q.obsolete,
        explanation: q.explanation,
        notes: q.notes,
        tags: q.tags,
      ),
      context: context == null
          ? null
          : QuestionContext(
              id: context.id,
              title: context.title,
              statement: context.statement,
              code: context.code,
              language: context.language,
            ),
      sourceName: source.name,
      isOfficial: source.isOfficial,
      topicTitle: topic.title,
      blockId: topic.blockId,
      position: q.position,
    );
  }
}
