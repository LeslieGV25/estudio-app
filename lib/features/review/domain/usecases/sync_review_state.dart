import '../../../../core/domain/session_mode.dart';
import '../../../progress/domain/entities/answer.dart';
import '../../../progress/domain/progress_repository.dart';
import '../leitner.dart';
import '../review_calendar.dart';
import '../review_repository.dart';
import '../review_state.dart';

/// Recalcula la caché de repaso a partir de las respuestas.
///
/// Nunca se suma sobre lo que había en la caché: siempre se rehace desde los
/// eventos con [Leitner.replay]. Así es idempotente: si la app se cierra
/// entre guardar una respuesta y actualizar la caché, la siguiente
/// sincronización deja todo bien.
class SyncReviewState {
  const SyncReviewState(this._progress, this._review, this._calendar);

  final ProgressRepository _progress;
  final ReviewRepository _review;
  final ReviewCalendar _calendar;

  /// Modos cuyas respuestas cuentan para el repaso. El simulacro se decidirá
  /// en la Fase 4 (allí se puede cambiar de opción antes de entregar).
  static const countedModes = {SessionMode.practice, SessionMode.review};

  /// Recalcula solo [questionIds] (tras responder una pregunta).
  Future<void> call(String packId, Iterable<String> questionIds) async {
    final ids = questionIds.toSet();
    if (ids.isEmpty) return;
    final byQuestion = _groupByQuestion(
      await _progress.packAnswers(
        packId,
        modes: countedModes,
        questionIds: ids,
      ),
    );
    await _review.saveStates(packId, {
      for (final id in ids)
        id: Leitner.replay(byQuestion[id] ?? const [], _calendar),
    });
  }

  /// Rehace la caché entera del pack.
  Future<void> rebuild(String packId) async {
    final byQuestion = _groupByQuestion(
      await _progress.packAnswers(packId, modes: countedModes),
    );
    final states = <String, ReviewState>{};
    for (final MapEntry(key: id, value: answers) in byQuestion.entries) {
      if (Leitner.replay(answers, _calendar) case final state?) {
        states[id] = state;
      }
    }
    await _review.replaceAll(packId, states);
  }

  /// Agrupa por pregunta conservando el orden cronológico.
  static Map<String, List<Answer>> _groupByQuestion(List<Answer> answers) {
    final byQuestion = <String, List<Answer>>{};
    for (final answer in answers) {
      byQuestion.putIfAbsent(answer.questionId, () => []).add(answer);
    }
    return byQuestion;
  }
}
