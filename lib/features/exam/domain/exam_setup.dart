import 'package:freezed_annotation/freezed_annotation.dart';

part 'exam_setup.freezed.dart';
part 'exam_setup.g.dart';

/// De dónde salen las preguntas del simulacro.
enum ExamKind {
  /// Un examen real tal cual: sus preguntas en orden, y las anuladas
  /// sustituidas por las de reserva.
  @JsonValue('real')
  realExam,

  /// Preguntas al azar de todos los exámenes que equivalen a cada ejercicio.
  /// Las de reserva entran como preguntas normales.
  @JsonValue('random')
  random,
}

/// Lo que elige la usuaria antes de empezar un simulacro. Se guarda en la
/// configuración de la sesión para saber después cómo se hizo.
@freezed
abstract class ExamSetup with _$ExamSetup {
  const factory ExamSetup({
    @Default(ExamKind.random) ExamKind kind,

    /// Examen elegido; solo en [ExamKind.realExam].
    String? sourceId,

    /// Ejercicio de simulacro elegido; `null` = simulacro completo (todos
    /// los ejercicios, uno detrás de otro).
    String? exerciseId,

    /// Solo preguntas de fuentes con plantilla oficial (en aleatorio).
    @Default(true) bool onlyOfficial,

    /// Incluir las preguntas marcadas como obsoletas (fuera por defecto).
    @Default(false) bool includeObsolete,
  }) = _ExamSetup;

  factory ExamSetup.fromJson(Map<String, dynamic> json) =>
      _$ExamSetupFromJson(json);
}
