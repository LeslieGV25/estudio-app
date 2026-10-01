import 'package:freezed_annotation/freezed_annotation.dart';

import '../../packs/domain/entities/study_question.dart';

part 'practice_filter.freezed.dart';
part 'practice_filter.g.dart';

/// Qué preguntas entran en una sesión de práctica.
///
/// Se guarda en la configuración de la sesión (JSON) para saber después con
/// qué filtros se practicó.
@freezed
abstract class PracticeFilter with _$PracticeFilter {
  const PracticeFilter._();

  const factory PracticeFilter({
    /// Temas y bloques elegidos. Una pregunta entra si su tema está en
    /// [topicIds] **o** su bloque en [blockIds]; si ambos están vacíos,
    /// entran todos los temas.
    @Default(<int>{}) Set<int> topicIds,
    @Default(<int>{}) Set<int> blockIds,

    /// Fuentes elegidas; vacío = todas.
    @Default(<String>{}) Set<String> sourceIds,

    /// Solo preguntas de fuentes con plantilla oficial.
    @Default(false) bool onlyOfficial,

    /// Incluir las preguntas marcadas como obsoletas (fuera por defecto).
    @Default(false) bool includeObsolete,

    /// Máximo de preguntas de la sesión; `null` = todas las que cumplan.
    int? questionCount,
  }) = _PracticeFilter;

  factory PracticeFilter.fromJson(Map<String, dynamic> json) =>
      _$PracticeFilterFromJson(json);

  bool matches(StudyQuestion q) {
    final question = q.question;
    // Las anuladas no se practican nunca. Siguen en la base de datos porque
    // el simulacro las necesita para sustituirlas por las de reserva.
    if (question.voided) return false;
    if (question.obsolete && !includeObsolete) return false;
    if (onlyOfficial && !q.isOfficial) return false;
    if (sourceIds.isNotEmpty && !sourceIds.contains(question.sourceId)) {
      return false;
    }
    final anySyllabusFilter = topicIds.isNotEmpty || blockIds.isNotEmpty;
    return !anySyllabusFilter ||
        topicIds.contains(q.topicId) ||
        blockIds.contains(q.blockId);
  }
}
