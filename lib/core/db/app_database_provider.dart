import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'app_database_provider.g.dart';

/// Única conexión a la base de datos durante toda la vida de la app.
/// En los tests se sobrescribe con una base de datos en memoria.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
