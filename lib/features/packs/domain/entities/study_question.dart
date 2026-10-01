import 'package:freezed_annotation/freezed_annotation.dart';

import 'pack_document.dart';

part 'study_question.freezed.dart';

/// Una pregunta lista para estudiar: la [Question] del pack junto con lo que
/// hace falta para mostrarla y filtrarla (contexto, fuente y tema).
///
/// La comparten práctica, simulacro y repaso; por eso vive en `packs` y no en
/// una feature concreta.
@freezed
abstract class StudyQuestion with _$StudyQuestion {
  const StudyQuestion._();

  const factory StudyQuestion({
    required Question question,

    /// Supuesto que se muestra encima del enunciado, si lo hay.
    QuestionContext? context,
    required String sourceName,

    /// `true` si la fuente trae respuestas de plantilla oficial.
    required bool isOfficial,
    required String topicTitle,
    required int blockId,

    /// Orden de la pregunta en el fichero del pack.
    required int position,
  }) = _StudyQuestion;

  String get id => question.id;
  int get topicId => question.topicId;
}
