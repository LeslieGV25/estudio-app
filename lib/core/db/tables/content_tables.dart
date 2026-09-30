import 'package:drift/drift.dart';

import '../../../features/packs/domain/entities/pack_document.dart';
import '../converters.dart';

// Tablas de CONTENIDO: reflejan un fichero de pack y se reemplazan enteras al
// actualizarlo. Todas cuelgan de `packs` con ON DELETE CASCADE y usan claves
// compuestas (pack_id, id): los ids solo son únicos dentro de su pack.
//
// Las filas se llaman `XxxRow` para no chocar con las entidades del dominio.
// La columna `position` guarda el orden del fichero original.

@DataClassName('PackRow')
class Packs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get version => text()();
  TextColumn get type => textEnum<PackType>()();
  TextColumn get language => text()();
  TextColumn get author => text().nullable()();
  TextColumn get updatedOn => text().nullable()();
  IntColumn get formatVersion => integer()();

  /// `simulacro.nota` del pack.
  TextColumn get examNote => text().nullable()();

  /// Primera instalación: se conserva al actualizar el pack.
  DateTimeColumn get installedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Columna `pack_id` común a todas las tablas de contenido.
mixin PackContent on Table {
  TextColumn get packId =>
      text().references(Packs, #id, onDelete: KeyAction.cascade)();
}

@DataClassName('BlockRow')
class Blocks extends Table with PackContent {
  IntColumn get id => integer()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {packId, id};
}

@DataClassName('TopicRow')
class Topics extends Table with PackContent {
  IntColumn get id => integer()();
  IntColumn get blockId => integer()();
  TextColumn get title => text()();

  @override
  Set<Column> get primaryKey => {packId, id};
}

@DataClassName('SourceRow')
class Sources extends Table with PackContent {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get type => textEnum<SourceType>()();
  TextColumn get name => text()();
  BoolColumn get isOfficial => boolean()();
  TextColumn get date => text().nullable()();
  TextColumn get call => text().nullable()();
  TextColumn get shift => text().nullable()();
  TextColumn get answersOrigin => textEnum<AnswersOrigin>().nullable()();

  @override
  Set<Column> get primaryKey => {packId, id};
}

/// El id de un ejercicio solo es único dentro de su fuente.
@DataClassName('SourceExerciseRow')
class SourceExercises extends Table with PackContent {
  TextColumn get sourceId => text()();
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  IntColumn get optionCount => integer()();
  TextColumn get examExerciseId => text().nullable()();

  @override
  Set<Column> get primaryKey => {packId, sourceId, id};
}

@DataClassName('ContextRow')
class QuestionContexts extends Table with PackContent {
  @override
  String get tableName => 'contexts';

  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get title => text()();
  TextColumn get statement => text()();
  TextColumn get code => text().nullable()();
  TextColumn get language => text().nullable()();

  @override
  Set<Column> get primaryKey => {packId, id};
}

@DataClassName('QuestionRow')
@TableIndex(name: 'questions_by_topic', columns: {#packId, #topicId})
@TableIndex(name: 'questions_by_source', columns: {#packId, #sourceId})
class Questions extends Table with PackContent {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get sourceId => text()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get number => text().nullable()();
  IntColumn get topicId => integer()();
  TextColumn get contextId => text().nullable()();
  TextColumn get statement => text()();
  TextColumn get options => text().map(const OptionsConverter())();
  TextColumn get correctKey => text().nullable()();
  BoolColumn get isReserve => boolean()();
  BoolColumn get voided => boolean()();
  TextColumn get provisionalKey => text().nullable()();
  BoolColumn get obsolete => boolean()();
  TextColumn get explanation => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get tags => text().map(const StringListConverter())();

  @override
  Set<Column> get primaryKey => {packId, id};
}

/// Apuntes por tema.
@DataClassName('NoteRow')
class Notes extends Table with PackContent {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  IntColumn get topicId => integer()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  BoolColumn get isOfficial => boolean()();

  @override
  Set<Column> get primaryKey => {packId, id};
}

/// Ejercicios de simulacro tal como vienen en el pack. Las reglas editadas
/// por la usuaria van en `settings`, para que actualizar el pack no las pise.
@DataClassName('ExamExerciseRow')
class ExamExercises extends Table with PackContent {
  TextColumn get id => text()();
  IntColumn get position => integer()();
  TextColumn get name => text()();
  IntColumn get questionCount => integer()();
  IntColumn get reserveCount => integer()();
  IntColumn get optionCount => integer()();
  IntColumn get durationMin => integer().nullable()();
  BoolColumn get hasCaseStudies => boolean()();
  TextColumn get scoring => text().map(const ScoringConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {packId, id};
}
