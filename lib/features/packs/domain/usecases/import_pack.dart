import '../../../settings/domain/settings_repository.dart';
import '../entities/pack_document.dart';
import '../pack_parser.dart';
import '../repositories/pack_repository.dart';
import '../semver.dart';

/// Qué ha pasado al importar un fichero de pack.
sealed class ImportOutcome {
  const ImportOutcome(this.pack);

  final PackDocument pack;
}

/// No había ningún pack con ese id: se ha instalado.
final class PackInstalled extends ImportOutcome {
  const PackInstalled(super.pack);
}

/// Había una versión anterior: se ha actualizado sin preguntar.
final class PackUpdated extends ImportOutcome {
  const PackUpdated(super.pack, {required this.previousVersion});

  final String previousVersion;
}

/// Ya está instalada la misma versión o una más nueva. No se ha guardado
/// nada: la UI debe preguntar y, si la usuaria acepta, llamar a
/// [ImportPack.replace].
final class ImportNeedsConfirmation extends ImportOutcome {
  const ImportNeedsConfirmation(super.pack, {required this.installedVersion});

  final String installedVersion;

  /// `true` si el fichero trae una versión anterior a la instalada.
  bool get isDowngrade =>
      SemVer.parse(installedVersion) > SemVer.parse(pack.info.version);
}

/// Importa un pack desde los bytes de un fichero `*.pack.json`.
///
/// Regla de `CLAUDE.md`: si el `pack.id` ya existe, una versión mayor
/// actualiza directamente; una igual o menor necesita confirmación.
class ImportPack {
  const ImportPack(
    this._packs,
    this._settings, {
    this._parser = const PackParser(),
  });

  final PackRepository _packs;
  final SettingsRepository _settings;
  final PackParser _parser;

  /// Lanza `InvalidPackException` si el fichero no es un pack válido.
  Future<ImportOutcome> call(List<int> bytes) async {
    final pack = _parser.parse(bytes);
    final installed = await _packs.findById(pack.info.id);

    if (installed == null) {
      await _save(pack);
      return PackInstalled(pack);
    }
    if (SemVer.parse(pack.info.version) > SemVer.parse(installed.version)) {
      await _save(pack);
      return PackUpdated(pack, previousVersion: installed.version);
    }
    return ImportNeedsConfirmation(pack, installedVersion: installed.version);
  }

  /// Reemplaza el pack instalado tras la confirmación de la usuaria.
  Future<void> replace(PackDocument pack) => _save(pack);

  /// Guarda el pack y, si no había ningún pack activo, lo activa: así la
  /// primera importación deja la app lista para estudiar.
  Future<void> _save(PackDocument pack) async {
    await _packs.save(pack);
    if (await _settings.getActivePackId() == null) {
      await _settings.setActivePackId(pack.info.id);
    }
  }
}
