import '../../../../core/domain/session_mode.dart';
import '../../../exam/domain/exam_session_config.dart';
import '../../../exam/domain/exam_setup.dart';
import '../../../exam/domain/usecases/load_exam_result.dart';
import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/progress_repository.dart';
import '../exam_history.dart';

/// Reúne los simulacros del pack con su resultado.
///
/// Cada resultado sale de [LoadExamResult], el mismo que usa la pantalla del
/// simulacro: la nota es la recalculada con el pack de hoy, y el historial y
/// el resultado nunca dicen cosas distintas.
class LoadExamHistory {
  const LoadExamHistory(this._content, this._progress, this._loadResult);

  final PackContentRepository _content;
  final ProgressRepository _progress;
  final LoadExamResult _loadResult;

  Future<ExamHistory> call(String packId) async {
    final sessions = await _progress.packSessions(
      packId,
      modes: {SessionMode.exam},
    );
    final outline = await _content.outline(packId);
    final rules = await _content.examRules(packId);
    final sourceNames = {for (final s in outline.sources) s.id: s.name};

    final entries = <ExamHistoryEntry>[];
    for (final session in sessions) {
      final config = ExamSessionConfig.fromJson(session.config);
      // Un simulacro completo son varias sesiones enlazadas: se entra por la
      // primera.
      if (config.previousSessionId != null) continue;
      final result = await _loadResult(session.id);
      if (result == null) continue;
      final setup = config.setup;
      entries.add(
        ExamHistoryEntry(
          result: result,
          setup: setup,
          sourceName: setup.kind == ExamKind.realExam
              ? sourceNames[setup.sourceId]
              : null,
        ),
      );
    }
    return ExamHistory.from(
      entries,
      exerciseOrder: [for (final e in rules.exercises) e.id],
    );
  }
}
