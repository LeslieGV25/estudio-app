import 'package:freezed_annotation/freezed_annotation.dart';

import 'pack_document.dart';

part 'installed_pack.freezed.dart';

/// Resumen de un pack instalado, para listarlo sin cargar su contenido.
@freezed
abstract class InstalledPack with _$InstalledPack {
  const factory InstalledPack({
    required String id,
    required String name,
    String? description,
    required String version,
    required PackType type,
    required String language,
    String? author,

    /// Todas las preguntas del pack, anuladas incluidas.
    required int questionCount,
    required DateTime installedAt,
    required DateTime updatedAt,
  }) = _InstalledPack;
}
