import 'package:drift/drift.dart';

import '../../domain/session_mode.dart';
import '../../utils/ids.dart';
import '../converters.dart';

// Tablas de DATOS DE USUARIO: nunca se tocan al importar, actualizar o borrar
// un pack. Por eso no tienen clave foránea hacia `packs` (se enlazan con el
// contenido por pack_id + question_id) y sobreviven a que el pack desaparezca.
//
// Preparadas para sincronizar en el futuro (CLAUDE.md, reglas 2–4):
// ids UUID v4 generados en el cliente, fechas en UTC y `user_id`, que vale
// 'local' mientras no haya login.

const localUserId = 'local';

/// `user_id` común a las tablas de usuario.
mixin UserOwned on Table {
  TextColumn get userId => text().withDefault(const Constant(localUserId))();
}

@DataClassName('SessionRow')
class Sessions extends Table with UserOwned {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get packId => text()();
  TextColumn get mode => textEnum<SessionMode>()();
  TextColumn get config => text().map(const JsonMapConverter())();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();

  /// Nota final como texto decimal («4.750»): se calcula con `Decimal` y se
  /// guarda exacta, sin pasar por `double`.
  TextColumn get score => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(nowUtc)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(nowUtc)();

  /// Borrado lógico: una sesión borrada sigue existiendo para sincronizar.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Una fila por respuesta: evento inmutable (solo INSERT; los triggers de
/// `answers_triggers.drift` impiden UPDATE y DELETE). Estadísticas y repaso se
/// derivan de aquí, y sincronizar es subir las filas nuevas.
///
/// Por ser inmutable no lleva `updated_at` ni `deleted_at`: `answered_at` es
/// su fecha de creación.
@DataClassName('AnswerRow')
@TableIndex(name: 'answers_by_question', columns: {#packId, #questionId})
@TableIndex(name: 'answers_by_session', columns: {#sessionId})
class Answers extends Table with UserOwned {
  TextColumn get id => text().clientDefault(newId)();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get packId => text()();
  TextColumn get questionId => text()();

  /// Letra elegida; `null` = en blanco.
  TextColumn get chosen => text().nullable()();
  BoolColumn get isCorrect => boolean()();
  IntColumn get timeMs => integer()();
  DateTimeColumn get answeredAt => dateTime().clientDefault(nowUtc)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Estado de Leitner por pregunta. Es una caché: se puede reconstruir
/// entera a partir de `answers`, por eso no necesita borrado lógico.
@DataClassName('ReviewStateRow')
class ReviewStates extends Table with UserOwned {
  @override
  String get tableName => 'review_state';

  TextColumn get packId => text()();
  TextColumn get questionId => text()();
  // El getter se referencia a sí mismo dentro de check(): es la forma que
  // documenta Drift para las restricciones CHECK de una columna.
  // ignore: recursive_getters
  IntColumn get box => integer().check(box.isBetweenValues(0, 4))();
  IntColumn get correctStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(nowUtc)();

  @override
  Set<Column> get primaryKey => {userId, packId, questionId};
}

/// Preferencias clave → valor (pack activo, reglas de simulacro editadas…).
/// Clave-valor para no tener que migrar el esquema con cada preferencia nueva.
@DataClassName('SettingRow')
class Settings extends Table with UserOwned {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().clientDefault(nowUtc)();

  @override
  Set<Column> get primaryKey => {userId, key};
}
