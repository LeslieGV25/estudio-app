import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../settings/data/settings_providers.dart';
import '../data/pack_providers.dart';
import '../domain/entities/pack_document.dart';
import '../domain/pack_parser.dart';
import '../domain/usecases/import_pack.dart';
import 'packs_providers.dart';

part 'packs_controller.g.dart';

/// Resultado de «Importar pack» visto desde la pantalla.
sealed class ImportFlowResult {
  const ImportFlowResult();
}

/// La usuaria cerró el selector sin elegir fichero.
final class ImportCancelled extends ImportFlowResult {
  const ImportCancelled();
}

final class ImportFinished extends ImportFlowResult {
  const ImportFinished(this.outcome);

  final ImportOutcome outcome;
}

final class ImportRejected extends ImportFlowResult {
  const ImportRejected(this.errors);

  final List<String> errors;
}

/// Acciones de la pantalla de packs. El estado indica si hay una operación
/// en curso (`isLoading`), para mostrar el progreso y bloquear botones.
///
/// Solo orquesta: las reglas están en los casos de uso. Los diálogos los
/// decide la pantalla según el resultado que devuelve cada acción.
@riverpod
class PacksController extends _$PacksController {
  @override
  FutureOr<void> build() {}

  Future<ImportFlowResult> importFromFile() async {
    final bytes = await ref.read(packFilePickerProvider).pickPackFile();
    if (bytes == null) return const ImportCancelled();
    return _busy(() async {
      try {
        return ImportFinished(await ref.read(importPackProvider)(bytes));
      } on InvalidPackException catch (e) {
        return ImportRejected(e.errors);
      }
    });
  }

  /// Tras confirmar en el diálogo de «misma versión o anterior».
  Future<void> replace(PackDocument pack) =>
      _busy(() => ref.read(importPackProvider).replace(pack));

  Future<void> delete(String packId) =>
      _busy(() => ref.read(deletePackProvider)(packId));

  Future<void> activate(String packId) =>
      ref.read(settingsRepositoryProvider).setActivePackId(packId);

  Future<T> _busy<T>(Future<T> Function() action) async {
    state = const AsyncLoading();
    try {
      return await action();
    } finally {
      if (ref.mounted) state = const AsyncData(null);
    }
  }
}
