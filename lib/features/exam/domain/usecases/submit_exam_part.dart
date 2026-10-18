import '../../../../core/utils/ids.dart';
import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../practice/domain/grading.dart';
import '../../../progress/domain/progress_repository.dart';
import '../../../review/domain/usecases/sync_review_state.dart';
import '../exam_session_config.dart';
import '../score_calculator.dart';

/// Entrega un ejercicio de simulacro (a mano o porque se acabó el tiempo).
///
/// El borrador se convierte en una respuesta por pregunta (las no marcadas,
/// en blanco), se calcula la nota y todo se guarda en una transacción.
class SubmitExamPart {
  const SubmitExamPart(this._content, this._progress, this._syncReview);

  final PackContentRepository _content;
  final ProgressRepository _progress;
  final SyncReviewState _syncReview;

  /// Lanza [StateError] si la sesión no existe o ya se entregó.
  Future<void> call(String sessionId) async {
    final session = await _progress.findSession(sessionId);
    if (session == null) throw StateError('La sesión $sessionId no existe');
    if (session.isFinished) {
      throw StateError('La sesión $sessionId ya se entregó');
    }
    final config = ExamSessionConfig.fromJson(session.config);
    // Las que el pack ya no tenga (se actualizó a mitad) no se pueden
    // corregir y se omiten.
    final questions = await _content.questionsByIds(
      session.packId,
      config.paper.questionIds,
    );

    final answers = <NewAnswer>[];
    var correct = 0, wrong = 0, blank = 0;
    for (final q in questions) {
      final chosen = config.choices[q.id];
      final isCorrect = isCorrectAnswer(q.question, chosen);
      answers.add((
        questionId: q.id,
        chosen: chosen,
        isCorrect: isCorrect,
        timeMs: config.timeMs[q.id] ?? 0,
      ));
      // Una anulada después de empezar se guarda, pero no es valorable.
      if (q.question.voided) continue;
      if (chosen == null) {
        blank++;
      } else if (isCorrect) {
        correct++;
      } else {
        wrong++;
      }
    }
    final scoring = config.paper.scoring;
    final score = scoring == null
        ? null
        : ScoreCalculator.score(
            scoring,
            ExamTally(correct: correct, wrong: wrong, blank: blank),
          );

    await _progress.submitSession(
      sessionId,
      answers: answers,
      // El borrador ya está en `answers`. El siguiente ejercicio recibe su
      // id ahora y se crea al empezarlo (StartExam.next).
      config: config
          .copyWith(
            choices: const {},
            timeMs: const {},
            nextSessionId: config.pending.isEmpty ? null : newId(),
          )
          .toJson(),
      score: score?.scoreText,
    );
    await _syncReview(session.packId, [for (final a in answers) a.questionId]);
  }
}
