import 'package:freezed_annotation/freezed_annotation.dart';

import 'practice_filter.dart';

part 'practice_session_config.freezed.dart';
part 'practice_session_config.g.dart';

/// Lo que se guarda en `sessions.config` de una sesión con feedback
/// inmediato: práctica y también repaso (que no tiene filtro). Lo que las
/// distingue es `sessions.mode`.
///
/// Las preguntas se guardan ya elegidas y en orden: así la sesión se puede
/// reanudar (la siguiente es la primera sin respuesta) y el resumen se
/// reconstruye desde la base de datos.
@freezed
abstract class PracticeSessionConfig with _$PracticeSessionConfig {
  // explicitToJson: el filtro anidado se guarda como mapa y no como objeto.
  // Es la forma que documenta freezed; el analizador no sabe que la
  // anotación acaba en la clase generada.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory PracticeSessionConfig({
    required List<String> questionIds,

    /// Filtro usado; `null` en una sesión de «repasar estas».
    PracticeFilter? filter,

    /// Sesión de la que salen las preguntas en «repasar estas».
    String? retryOf,
  }) = _PracticeSessionConfig;

  factory PracticeSessionConfig.fromJson(Map<String, dynamic> json) =>
      _$PracticeSessionConfigFromJson(json);
}
