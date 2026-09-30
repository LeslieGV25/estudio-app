import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:estudio_app/core/db/app_database.dart';

/// Base de datos SQLite en memoria, nueva en cada llamada.
AppDatabase newTestDatabase() => AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    // Evita avisos de timers pendientes al cerrar streams en flutter_test.
    closeStreamsSynchronously: true,
  ),
);
