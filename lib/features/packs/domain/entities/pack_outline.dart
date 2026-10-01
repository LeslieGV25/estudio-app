import 'package:freezed_annotation/freezed_annotation.dart';

import 'pack_document.dart';

part 'pack_outline.freezed.dart';

/// Temario y fuentes de un pack instalado: lo necesario para elegir qué
/// estudiar sin cargar las preguntas.
@freezed
abstract class PackOutline with _$PackOutline {
  const factory PackOutline({
    required List<Block> blocks,
    required List<Topic> topics,
    required List<Source> sources,
  }) = _PackOutline;
}
