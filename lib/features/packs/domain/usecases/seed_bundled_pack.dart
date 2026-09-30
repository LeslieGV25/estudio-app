import '../../../settings/domain/settings_repository.dart';
import '../pack_parser.dart';
import '../repositories/pack_repository.dart';
import '../semver.dart';

enum SeedResult {
  /// Primer arranque: el pack incluido se ha instalado.
  installed,

  /// La app trae una versión más nueva del pack incluido y se ha actualizado.
  updated,

  /// No había nada que hacer.
  unchanged,
}

/// Instala el pack que viene dentro de la app (asset) en el primer arranque.
///
/// - Se instala **una sola vez**: queda una marca en ajustes, y si la usuaria
///   lo borra no vuelve a aparecer.
/// - Si una versión nueva de la app trae el pack con una versión mayor, se
///   actualiza, pero solo si la usuaria todavía lo tiene instalado.
class SeedBundledPack {
  const SeedBundledPack(
    this._packs,
    this._settings, {
    required this._loadBundledPack,
    this._parser = const PackParser(),
  });

  final PackRepository _packs;
  final SettingsRepository _settings;

  /// Lee los bytes del asset. Se inyecta para que el dominio no dependa de
  /// Flutter (`rootBundle`) y para poder probarlo con un fichero cualquiera.
  final Future<List<int>> Function() _loadBundledPack;
  final PackParser _parser;

  Future<SeedResult> call() async {
    final pack = _parser.parse(await _loadBundledPack());
    final installed = await _packs.findById(pack.info.id);
    final isNewer =
        installed != null &&
        SemVer.parse(pack.info.version) > SemVer.parse(installed.version);

    if (!await _settings.isBundledPackSeeded()) {
      // Si ya estaba (p. ej. un arranque anterior se cortó antes de guardar
      // la marca), solo se sobrescribe con una versión más nueva.
      if (installed == null || isNewer) await _packs.save(pack);
      if (await _settings.getActivePackId() == null) {
        await _settings.setActivePackId(pack.info.id);
      }
      await _settings.markBundledPackSeeded();
      return installed == null
          ? SeedResult.installed
          : isNewer
          ? SeedResult.updated
          : SeedResult.unchanged;
    }

    if (isNewer) {
      await _packs.save(pack);
      return SeedResult.updated;
    }
    return SeedResult.unchanged;
  }
}
