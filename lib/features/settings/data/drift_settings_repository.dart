import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables/user_tables.dart';
import '../../../core/utils/ids.dart';
import '../domain/settings_repository.dart';

/// Implementa [SettingsRepository] sobre la tabla clave-valor `settings`.
class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {this._clock = nowUtc});

  final AppDatabase _db;
  final DateTime Function() _clock;

  static const _activePackKey = 'active_pack_id';
  static const _bundledSeededKey = 'bundled_pack_seeded';

  @override
  Stream<String?> watchActivePackId() =>
      _byKey(_activePackKey).watchSingleOrNull().map((row) => row?.value);

  @override
  Future<String?> getActivePackId() async =>
      (await _byKey(_activePackKey).getSingleOrNull())?.value;

  @override
  Future<void> setActivePackId(String? packId) => packId == null
      ? (_db.delete(_db.settings)..where(
              (s) =>
                  s.userId.equals(localUserId) & s.key.equals(_activePackKey),
            ))
            .go()
      : _put(_activePackKey, packId);

  @override
  Future<bool> isBundledPackSeeded() async =>
      (await _byKey(_bundledSeededKey).getSingleOrNull())?.value == 'true';

  @override
  Future<void> markBundledPackSeeded() => _put(_bundledSeededKey, 'true');

  SimpleSelectStatement<$SettingsTable, SettingRow> _byKey(String key) =>
      _db.select(_db.settings)
        ..where((s) => s.userId.equals(localUserId) & s.key.equals(key));

  Future<void> _put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: Value(_clock()),
        ),
      );
}
