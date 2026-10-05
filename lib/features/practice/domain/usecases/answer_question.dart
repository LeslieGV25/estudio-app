import '../../../packs/domain/entities/study_question.dart';
import '../../../progress/domain/entities/answer.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../../../review/domain/usecases/sync_review_state.dart';
import '../grading.dart';
import '../practice_session_config.dart';

/// Corrige una respuesta con feedback inmediato (práctica y repaso), la
/// guarda como evento y actualiza el repaso de esa pregunta.
///
/// Con feedback inmediato cada pregunta se responde una sola vez por sesión.
class AnswerQuestion {
  const AnswerQuestion(this._progress, this._syncReview);

  final ProgressRepository _progress;
  final SyncReviewState _syncReview;

  /// [chosen] `null` = en blanco («Saltar»). Lanza [StateError] si la
  /// pregunta no es de la sesión, está anulada o ya se respondió.
  Future<Answer> call({
    required StudySession session,
    required StudyQuestion question,
    required String? chosen,
    required int timeMs,
  }) async {
    final config = PracticeSessionConfig.fromJson(session.config);
    if (!config.questionIds.contains(question.id)) {
      throw StateError('La pregunta ${question.id} no es de esta sesión');
    }
    if (question.question.voided) {
      // Solo pasa si el pack se actualizó a mitad de sesión y anuló esta
      // pregunta: la pantalla ya la salta, esto es la última defensa.
      throw StateError('La pregunta ${question.id} está anulada');
    }
    final previous = await _progress.sessionAnswers(session.id);
    if (previous.any((a) => a.questionId == question.id)) {
      throw StateError('La pregunta ${question.id} ya se respondió');
    }
    final answer = await _progress.recordAnswer(
      sessionId: session.id,
      questionId: question.id,
      chosen: chosen,
      isCorrect: isCorrectAnswer(question.question, chosen),
      timeMs: timeMs,
    );
    // Si la app se cerrase justo aquí, la caché quedaría atrasada; la
    // reconstrucción al arrancar (SyncReviewState.rebuild) la pone al día.
    await _syncReview(session.packId, [question.id]);
    return answer;
  }
}
