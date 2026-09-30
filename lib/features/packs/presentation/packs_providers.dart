import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../settings/data/settings_providers.dart';
import '../data/pack_providers.dart';
import '../domain/entities/installed_pack.dart';
import '../domain/usecases/delete_pack.dart';
import '../domain/usecases/import_pack.dart';
import '../domain/usecases/seed_bundled_pack.dart';

part 'packs_providers.g.dart';

@riverpod
ImportPack importPack(Ref ref) => ImportPack(
  ref.watch(packRepositoryProvider),
  ref.watch(settingsRepositoryProvider),
);

@riverpod
DeletePack deletePack(Ref ref) => DeletePack(
  ref.watch(packRepositoryProvider),
  ref.watch(settingsRepositoryProvider),
);

/// Instala o actualiza el pack incluido. Se ejecuta una vez por arranque
/// (keepAlive) y la pantalla muestra un indicador de carga mientras tanto.
@Riverpod(keepAlive: true)
Future<SeedResult> bundledPackSeed(Ref ref) => SeedBundledPack(
  ref.watch(packRepositoryProvider),
  ref.watch(settingsRepositoryProvider),
  loadBundledPack: ref.watch(bundledPackLoaderProvider),
)();

@riverpod
Stream<List<InstalledPack>> installedPacks(Ref ref) =>
    ref.watch(packRepositoryProvider).watchInstalledPacks();

@riverpod
Stream<String?> activePackId(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchActivePackId();
