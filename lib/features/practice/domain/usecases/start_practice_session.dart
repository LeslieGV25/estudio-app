import '../../../../core/domain/session_mode.dart';
import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../practice_plan.dart';
import '../practice_session_config.dart';

sealed class PracticeStart {
  const PracticeStart();
}

final class PracticeStarted extends PracticeStart {
  const PracticeStarted(this.session, this.config);

  final StudySession session;
  final PracticeSessionConfig config;
}

/// Ninguna pregunta cumple el filtro: no se crea la sesión.
final class NoQuestionsMatch extends PracticeStart {
  const NoQuestionsMatch();
}

/// Crea sesiones de práctica.
class StartPracticeSession {
  const StartPracticeSession(this._content, this._progress);

  final PackContentRepository _content;
  final ProgressRepository _progress;

  /// Sesión nueva de [packId] con las preguntas ya elegidas en [plan] (la
  /// pantalla de configuración lo calcula y lo muestra antes de empezar).
  Future<PracticeStart> call(String packId, PracticePlan plan) => _start(
    packId,
    PracticeSessionConfig(questionIds: plan.questionIds, filter: plan.filter),
  );

  /// «Repasar estas»: sesión nueva con [questionIds] en el mismo orden.
  /// Se omiten las que ya no existan en el pack y las anuladas (p. ej. porque
  /// una actualización del pack anuló una pregunta que se había fallado).
  Future<PracticeStart> retry(
    String packId,
    List<String> questionIds, {
    required String fromSessionId,
  }) async {
    final existing = await _content.questionsByIds(packId, questionIds);
    return _start(
      packId,
      PracticeSessionConfig(
        questionIds: [
          for (final q in existing)
            if (!q.question.voided) q.id,
        ],
        retryOf: fromSessionId,
      ),
    );
  }

  Future<PracticeStart> _start(
    String packId,
    PracticeSessionConfig config,
  ) async {
    if (config.questionIds.isEmpty) return const NoQuestionsMatch();
    final session = await _progress.startSession(
      packId: packId,
      mode: SessionMode.practice,
      config: config.toJson(),
    );
    return PracticeStarted(session, config);
  }
}
