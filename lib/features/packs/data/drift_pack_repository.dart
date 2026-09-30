import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/utils/ids.dart';
import '../domain/entities/installed_pack.dart';
import '../domain/entities/pack_document.dart';
import '../domain/repositories/pack_repository.dart';

class DriftPackRepository implements PackRepository {
  DriftPackRepository(this._db, {this._clock = nowUtc});

  final AppDatabase _db;
  final DateTime Function() _clock;

  @override
  Stream<List<InstalledPack>> watchInstalledPacks() =>
      _packsWithCount().watch().map((rows) => rows.map(_toEntity).toList());

  @override
  Future<InstalledPack?> findById(String packId) async {
    final query = _packsWithCount()..where(_db.packs.id.equals(packId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> save(PackDocument pack) async {
    final packId = pack.info.id;
    await _db.transaction(() async {
      final previous = await (_db.select(
        _db.packs,
      )..where((p) => p.id.equals(packId))).getSingleOrNull();
      final now = _clock();

      // Borrar la fila de `packs` elimina en cascada todo su contenido.
      // Las tablas de usuario no tienen clave foránea hacia `packs`, así que
      // sesiones, respuestas y repaso no se tocan.
      await (_db.delete(_db.packs)..where((p) => p.id.equals(packId))).go();

      await _db
          .into(_db.packs)
          .insert(
            _packRow(pack, installedAt: previous?.installedAt ?? now, now: now),
          );
      await _db.batch((b) => _insertContent(b, pack));
    });
  }

  @override
  Future<void> delete(String packId) =>
      (_db.delete(_db.packs)..where((p) => p.id.equals(packId))).go();

  // --- Consultas --------------------------------------------------------------

  late final _questionCount = _db.questions.id.count();

  JoinedSelectStatement<HasResultSet, dynamic> _packsWithCount() =>
      _db.select(_db.packs).join([
          leftOuterJoin(
            _db.questions,
            _db.questions.packId.equalsExp(_db.packs.id),
            useColumns: false,
          ),
        ])
        ..addColumns([_questionCount])
        ..groupBy([_db.packs.id])
        ..orderBy([OrderingTerm.asc(_db.packs.name)]);

  InstalledPack _toEntity(TypedResult row) {
    final pack = row.readTable(_db.packs);
    return InstalledPack(
      id: pack.id,
      name: pack.name,
      description: pack.description,
      version: pack.version,
      type: pack.type,
      language: pack.language,
      author: pack.author,
      questionCount: row.read(_questionCount) ?? 0,
      installedAt: pack.installedAt,
      updatedAt: pack.updatedAt,
    );
  }

  // --- Documento → filas ------------------------------------------------------

  PacksCompanion _packRow(
    PackDocument pack, {
    required DateTime installedAt,
    required DateTime now,
  }) {
    final info = pack.info;
    return PacksCompanion.insert(
      id: info.id,
      name: info.name,
      description: Value(info.description),
      version: info.version,
      type: info.type,
      language: info.language,
      author: Value(info.author),
      updatedOn: Value(info.updatedOn),
      formatVersion: pack.formatVersion,
      examNote: Value(pack.examRules?.note),
      installedAt: installedAt,
      updatedAt: now,
    );
  }

  void _insertContent(Batch b, PackDocument pack) {
    final packId = pack.info.id;
    b.insertAll(_db.blocks, [
      for (final block in pack.syllabus.blocks)
        BlocksCompanion.insert(packId: packId, id: block.id, name: block.name),
    ]);
    b.insertAll(_db.topics, [
      for (final topic in pack.syllabus.topics)
        TopicsCompanion.insert(
          packId: packId,
          id: topic.id,
          blockId: topic.blockId,
          title: topic.title,
        ),
    ]);
    b.insertAll(_db.sources, [
      for (final (i, source) in pack.sources.indexed)
        SourcesCompanion.insert(
          packId: packId,
          id: source.id,
          position: i,
          type: source.type,
          name: source.name,
          isOfficial: source.isOfficial,
          date: Value(source.date),
          call: Value(source.call),
          shift: Value(source.shift),
          answersOrigin: Value(source.answersOrigin),
        ),
    ]);
    b.insertAll(_db.sourceExercises, [
      for (final source in pack.sources)
        for (final (i, exercise) in source.exercises.indexed)
          SourceExercisesCompanion.insert(
            packId: packId,
            sourceId: source.id,
            id: exercise.id,
            position: i,
            name: exercise.name,
            optionCount: exercise.optionCount,
            examExerciseId: Value(exercise.examExerciseId),
          ),
    ]);
    b.insertAll(_db.questionContexts, [
      for (final (i, context) in pack.contexts.indexed)
        QuestionContextsCompanion.insert(
          packId: packId,
          id: context.id,
          position: i,
          title: context.title,
          statement: context.statement,
          code: Value(context.code),
          language: Value(context.language),
        ),
    ]);
    b.insertAll(_db.questions, [
      for (final (i, q) in pack.questions.indexed)
        QuestionsCompanion.insert(
          packId: packId,
          id: q.id,
          position: i,
          sourceId: q.sourceId,
          exerciseId: Value(q.exerciseId),
          number: Value(q.number),
          topicId: q.topicId,
          contextId: Value(q.contextId),
          statement: q.statement,
          options: q.options,
          correctKey: Value(q.correctKey),
          isReserve: q.isReserve,
          voided: q.voided,
          provisionalKey: Value(q.provisionalKey),
          obsolete: q.obsolete,
          explanation: Value(q.explanation),
          notes: Value(q.notes),
          tags: q.tags,
        ),
    ]);
    b.insertAll(_db.notes, [
      for (final (i, note) in pack.notes.indexed)
        NotesCompanion.insert(
          packId: packId,
          id: note.id,
          position: i,
          topicId: note.topicId,
          title: note.title,
          content: note.content,
          isOfficial: note.isOfficial,
        ),
    ]);
    b.insertAll(_db.examExercises, [
      for (final (i, e) in (pack.examRules?.exercises ?? const []).indexed)
        ExamExercisesCompanion.insert(
          packId: packId,
          id: e.id,
          position: i,
          name: e.name,
          questionCount: e.questionCount,
          reserveCount: e.reserveCount,
          optionCount: e.optionCount,
          durationMin: Value(e.durationMin),
          hasCaseStudies: e.hasCaseStudies,
          scoring: Value(e.scoring),
        ),
    ]);
  }
}
