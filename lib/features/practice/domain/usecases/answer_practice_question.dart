import '../../../packs/domain/entities/study_question.dart';
import '../../../progress/domain/entities/answer.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../grading.dart';
import '../practice_session_config.dart';

/// Corrige una respuesta de práctica y la guarda como evento.
///
/// En práctica el feedback es inmediato, así que cada pregunta se responde
/// una sola vez por sesión.
class AnswerPracticeQuestion {
  const AnswerPracticeQuestion(this._progress);

  final ProgressRepository _progress;

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
    return _progress.recordAnswer(
      sessionId: session.id,
      questionId: question.id,
      chosen: chosen,
      isCorrect: isCorrectAnswer(question.question, chosen),
      timeMs: timeMs,
    );
  }
}
