import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/session_mode.dart';
import '../../packs/domain/entities/study_question.dart';

part 'stats_filter.freezed.dart';

/// Qué preguntas entran según su fuente.
enum SourceFilter {
  all,

  /// Solo fuentes con plantilla oficial.
  official,

  /// Solo fuentes de estudio (sin plantilla oficial).
  study,
}

/// Qué respuestas y preguntas entran en las estadísticas.
@freezed
abstract class StatsFilter with _$StatsFilter {
  const StatsFilter._();

  const factory StatsFilter({
    /// Modos de sesión cuyas respuestas cuentan; por defecto, todos.
    @Default({SessionMode.practice, SessionMode.review, SessionMode.exam})
    Set<SessionMode> modes,
    @Default(SourceFilter.all) SourceFilter sources,

    /// Incluir las preguntas marcadas como obsoletas (fuera por defecto).
    @Default(false) bool includeObsolete,
  }) = _StatsFilter;

  /// La pregunta entra en las estadísticas (sus respuestas y la cobertura).
  /// Las anuladas no entran nunca: sus respuestas «no cuentan».
  bool matches(StudyQuestion q) {
    final question = q.question;
    if (question.voided) return false;
    if (question.obsolete && !includeObsolete) return false;
    return switch (sources) {
      SourceFilter.all => true,
      SourceFilter.official => q.isOfficial,
      SourceFilter.study => !q.isOfficial,
    };
  }
}
