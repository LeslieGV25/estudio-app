import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/packs/domain/entities/pack_document.dart';
import '../domain/session_mode.dart';
import '../utils/ids.dart';
import 'converters.dart';
import 'tables/content_tables.dart';
import 'tables/user_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    // Contenido de los packs
    Packs,
    Blocks,
    Topics,
    Sources,
    SourceExercises,
    QuestionContexts,
    Questions,
    Notes,
    ExamExercises,
    // Datos de la usuaria
    Sessions,
    Answers,
    ReviewStates,
    Settings,
  ],
  include: {'answers_triggers.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Súbelo al cambiar el esquema y añade el paso en [migration]
  /// (`dart run drift_dev make-migrations` genera los tests de migración).
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      // SQLite trae las claves foráneas desactivadas por defecto; sin esto
      // el ON DELETE CASCADE de las tablas de contenido no haría nada.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() => driftDatabase(
    name: 'estudio',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
