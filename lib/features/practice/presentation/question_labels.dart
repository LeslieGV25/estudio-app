import '../../packs/domain/entities/pack_document.dart';
import '../../packs/domain/entities/study_question.dart';

/// Origen de la pregunta: «Examen 28/04/2026 · Turno libre · Pregunta 7».
/// Las de estudio no suelen tener número y se quedan solo con la fuente.
String questionOrigin(StudyQuestion q) {
  final number = q.question.number;
  return number == null ? q.sourceName : '${q.sourceName} · Pregunta $number';
}

/// «Tema 35 · Herramientas CASE…».
String questionTopic(StudyQuestion q) => 'Tema ${q.topicId} · ${q.topicTitle}';

/// «b) 1978».
String optionLabel(Question question, String key) =>
    '$key) ${question.options[key] ?? ''}';
