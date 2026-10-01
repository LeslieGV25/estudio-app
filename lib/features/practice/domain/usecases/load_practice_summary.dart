import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/progress_repository.dart';
import '../../../progress/domain/session_summary.dart';
import '../practice_session_config.dart';

/// Reconstruye el resumen de una sesión de práctica desde la base de datos:
/// las preguntas salen de la configuración de la sesión y las respuestas de
/// sus eventos.
class LoadPracticeSummary {
  const LoadPracticeSummary(this._content, this._progress);

  final PackContentRepository _content;
  final ProgressRepository _progress;

  /// `null` si la sesión no existe.
  Future<SessionSummary?> call(String sessionId) async {
    final session = await _progress.findSession(sessionId);
    if (session == null) return null;
    final config = PracticeSessionConfig.fromJson(session.config);
    final questions = await _content.questionsByIds(
      session.packId,
      config.questionIds,
    );
    final answers = await _progress.sessionAnswers(sessionId);
    return SessionSummary.from(questions, answers);
  }
}
