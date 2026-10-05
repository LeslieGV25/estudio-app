import '../../../../core/domain/session_mode.dart';
import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../practice/domain/practice_session_config.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../review_overview.dart';
import '../review_repository.dart';

/// Crea una sesión de repaso con las preguntas pendientes ahora.
///
/// La sesión guarda sus preguntas ya elegidas (mismo formato que la
/// práctica), así que se puede reanudar y su resumen se reconstruye igual.
class StartReviewSession {
  const StartReviewSession(
    this._content,
    this._review,
    this._progress,
    this._clock,
  );

  final PackContentRepository _content;
  final ReviewRepository _review;
  final ProgressRepository _progress;
  final DateTime Function() _clock;

  /// Sesión con las [limit] pendientes más prioritarias (todas si es
  /// `null`); `null` si no hay ninguna pendiente.
  Future<StudySession?> call(String packId, {int? limit}) async {
    final overview = ReviewOverview.from(
      await _review.states(packId),
      await _content.questions(packId),
      _clock(),
    );
    final ids = overview.dueIds(limit: limit);
    if (ids.isEmpty) return null;
    return _progress.startSession(
      packId: packId,
      mode: SessionMode.review,
      config: PracticeSessionConfig(questionIds: ids).toJson(),
    );
  }
}
