import '../../../settings/domain/settings_repository.dart';
import '../repositories/pack_repository.dart';

/// Borra el contenido de un pack (el progreso se conserva) y, si era el
/// activo, activa otro o deja la app sin pack activo.
class DeletePack {
  const DeletePack(this._packs, this._settings);

  final PackRepository _packs;
  final SettingsRepository _settings;

  /// Devuelve el id del pack activo tras el borrado (`null` si no queda
  /// ninguno).
  Future<String?> call(String packId) async {
    await _packs.delete(packId);

    final activeId = await _settings.getActivePackId();
    if (activeId != packId) return activeId;

    // Era el activo: se pasa al primero que quede (orden alfabético).
    final remaining = await _packs.watchInstalledPacks().first;
    final nextId = remaining.firstOrNull?.id;
    await _settings.setActivePackId(nextId);
    return nextId;
  }
}
