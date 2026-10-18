import 'package:freezed_annotation/freezed_annotation.dart';

import 'exam_paper.dart';
import 'exam_setup.dart';

part 'exam_session_config.freezed.dart';
part 'exam_session_config.g.dart';

/// Lo que se guarda en `sessions.config` de una sesión de simulacro.
///
/// Cada ejercicio es una sesión (con su hora de inicio, que marca el
/// temporizador, y su nota). Un simulacro completo encadena varias:
/// [previousSessionId] y [nextSessionId] las enlazan, y [pending] guarda los
/// ejercicios que faltan, ya preparados al empezar.
///
/// Mientras no se entrega, las opciones marcadas son un **borrador** que se
/// guarda aquí con cada cambio (recargar la página no las pierde). Al
/// entregar se convierten en eventos de `answers`, uno por pregunta, y el
/// borrador se vacía.
@freezed
abstract class ExamSessionConfig with _$ExamSessionConfig {
  const ExamSessionConfig._();

  // explicitToJson: los objetos anidados se guardan como mapas.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory ExamSessionConfig({
    required ExamSetup setup,
    required ExamPaper paper,

    /// Ejercicios que vienen después de este en el simulacro completo.
    @Default(<ExamPaper>[]) List<ExamPaper> pending,
    String? previousSessionId,

    /// Se fija al entregar si hay ejercicios pendientes. La sesión se crea
    /// cuando la usuaria empieza el siguiente ejercicio (y su temporizador).
    String? nextSessionId,

    /// Borrador: pregunta → letra marcada. Las que no están, en blanco.
    @Default(<String, String>{}) Map<String, String> choices,

    /// Borrador: pregunta → milisegundos que ha estado en pantalla.
    @Default(<String, int>{}) Map<String, int> timeMs,

    /// Pregunta que se estaba viendo, para continuar en la misma.
    @Default(0) int currentIndex,
  }) = _ExamSessionConfig;

  factory ExamSessionConfig.fromJson(Map<String, dynamic> json) =>
      _$ExamSessionConfigFromJson(json);

  /// Marca [chosen] en [questionId]; `null` la deja en blanco.
  ExamSessionConfig withChoice(String questionId, String? chosen) {
    _checkQuestion(questionId);
    final updated = {...choices};
    if (chosen == null) {
      updated.remove(questionId);
    } else {
      updated[questionId] = chosen;
    }
    return copyWith(choices: updated);
  }

  /// Suma [ms] al tiempo de [questionId].
  ExamSessionConfig withTimeSpent(String questionId, int ms) {
    _checkQuestion(questionId);
    return copyWith(
      timeMs: {...timeMs, questionId: (timeMs[questionId] ?? 0) + ms},
    );
  }

  int get answeredCount => paper.questionIds.where(choices.containsKey).length;

  int get blankCount => paper.questionIds.length - answeredCount;

  /// Hora límite de entrega; `null` si el ejercicio no tiene tiempo.
  DateTime? deadline(DateTime startedAt) => paper.durationMin == null
      ? null
      : startedAt.add(Duration(minutes: paper.durationMin!));

  void _checkQuestion(String questionId) {
    if (!paper.questionIds.contains(questionId)) {
      throw StateError('La pregunta $questionId no es de este ejercicio');
    }
  }
}
