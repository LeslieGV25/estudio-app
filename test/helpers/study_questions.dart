import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/entities/study_question.dart';

/// [StudyQuestion] mínima para tests de dominio; solo se indica lo que
/// importa en cada caso.
StudyQuestion studyQuestion(
  String id, {
  int position = 0,
  int topicId = 1,
  int blockId = 0,
  String sourceId = 'examen',
  bool isOfficial = true,
  String? contextId,
  String? correctKey = 'a',
  bool voided = false,
  String? provisionalKey,
  bool obsolete = false,
}) => StudyQuestion(
  question: Question(
    id: id,
    sourceId: sourceId,
    topicId: topicId,
    contextId: contextId,
    statement: 'Enunciado $id',
    options: const {'a': 'Opción A', 'b': 'Opción B', 'c': 'Opción C'},
    correctKey: voided ? null : correctKey,
    voided: voided,
    provisionalKey: provisionalKey,
    obsolete: obsolete,
  ),
  context: contextId == null
      ? null
      : QuestionContext(id: contextId, title: contextId, statement: '…'),
  sourceName: 'Fuente $sourceId',
  isOfficial: isOfficial,
  topicTitle: 'Tema $topicId',
  blockId: blockId,
  position: position,
);
