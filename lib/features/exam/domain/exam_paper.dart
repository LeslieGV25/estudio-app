import 'package:freezed_annotation/freezed_annotation.dart';

import '../../packs/domain/entities/pack_document.dart';

part 'exam_paper.freezed.dart';
part 'exam_paper.g.dart';

/// Un ejercicio del simulacro ya preparado: sus preguntas, en orden, y las
/// reglas con las que se corrige.
///
/// Las reglas se copian aquí al empezar: si el pack se actualiza (o, en la
/// Fase 6, la usuaria las edita), los simulacros ya hechos no cambian de
/// duración ni de puntuación.
@freezed
abstract class ExamPaper with _$ExamPaper {
  const ExamPaper._();

  // explicitToJson: la puntuación anidada se guarda como mapa.
  // ignore: invalid_annotation_target
  @JsonSerializable(explicitToJson: true)
  const factory ExamPaper({
    /// Ejercicio de simulacro del pack (`ej1`…).
    required String exerciseId,
    required String name,

    /// Preguntas que pide el ejercicio (`num_preguntas`).
    required int questionCount,

    /// Preguntas que se muestran, en orden. Son las valorables: en un examen
    /// real, las no anuladas y después las reservas que las sustituyen.
    required List<String> questionIds,

    /// Anuladas del examen real, en su orden (no se muestran).
    @Default(<String>[]) List<String> voidedIds,

    /// Anulada → reserva que la sustituye.
    @Default(<String, String>{}) Map<String, String> replacements,

    /// `null` = sin límite de tiempo.
    int? durationMin,

    /// `null` = el pack no dice cómo se puntúa: se muestran los aciertos,
    /// pero no hay nota.
    Scoring? scoring,
  }) = _ExamPaper;

  factory ExamPaper.fromJson(Map<String, dynamic> json) =>
      _$ExamPaperFromJson(json);

  /// Anuladas que ninguna reserva sustituyó: restan preguntas valorables.
  List<String> get unreplacedVoidedIds => [
    for (final id in voidedIds)
      if (!replacements.containsKey(id)) id,
  ];

  /// Tiene menos preguntas de las que pide el ejercicio (examen incompleto
  /// en el pack, anuladas sin reserva o pocas preguntas para el azar).
  bool get isShort => questionIds.length < questionCount;
}
