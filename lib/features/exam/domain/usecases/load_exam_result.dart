import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../../../progress/domain/session_summary.dart';
import '../exam_paper.dart';
import '../exam_session_config.dart';
import '../score_calculator.dart';

enum ExamPartStatus {
  /// Entregado y corregido.
  graded,

  /// Entregado, pero un ejercicio anterior no llegó a la nota mínima: como
  /// en el examen real, no se corrige (se muestran las respuestas, sin nota).
  notCorrected,

  /// Empezado y sin entregar.
  inProgress,

  /// No se llegó a empezar (se terminó el simulacro antes).
  notTaken,
}

class ExamPartResult {
  const ExamPartResult({
    required this.paper,
    required this.status,
    this.session,
    this.summary,
    this.score,
  });

  final ExamPaper paper;
  final ExamPartStatus status;

  /// `null` si no se llegó a empezar.
  final StudySession? session;
  final SessionSummary? summary;

  /// Nota recalculada con el pack de hoy; `null` si el ejercicio no tiene
  /// puntuación o aún no se ha entregado.
  final ExamScore? score;

  /// Nota guardada al entregar (`sessions.score`).
  String? get submittedScoreText => session?.score;

  /// La nota de hoy no es la de la entrega (el pack anuló preguntas
  /// después): la pantalla muestra las dos.
  bool get scoreChangedSinceSubmit =>
      score != null &&
      submittedScoreText != null &&
      score!.scoreText != submittedScoreText;
}

/// Resultado de un simulacro: todos sus ejercicios, en orden.
class ExamResult {
  const ExamResult(this.parts);

  final List<ExamPartResult> parts;

  StudySession get firstSession => parts.first.session!;
}

/// Reconstruye el resultado de un simulacro desde la base de datos.
///
/// La nota se recalcula con las respuestas guardadas y las preguntas como
/// están hoy en el pack: si después se anula una pregunta, deja de ser
/// valorable y la nota cambia, como cuando el tribunal publica la plantilla
/// definitiva. `sessions.score` guarda la nota del momento de la entrega.
class LoadExamResult {
  const LoadExamResult(this._content, this._progress);

  final PackContentRepository _content;
  final ProgressRepository _progress;

  /// Desde cualquiera de sus sesiones; `null` si la sesión no existe.
  Future<ExamResult?> call(String sessionId) async {
    var first = await _progress.findSession(sessionId);
    if (first == null) return null;
    // Al primer ejercicio…
    for (
      var previousId = _config(first).previousSessionId;
      previousId != null;
      previousId = _config(first).previousSessionId
    ) {
      final previous = await _progress.findSession(previousId);
      if (previous == null) break;
      first = previous;
    }
    // …y de ahí, uno detrás de otro.
    final parts = <ExamPartResult>[];
    var failedBefore = false;
    StudySession? current = first;
    late ExamSessionConfig lastConfig;
    while (current != null) {
      final config = lastConfig = _config(current);
      final part = await _part(current, config, failedBefore: failedBefore);
      parts.add(part);
      failedBefore = failedBefore || part.score?.passed == false;
      final nextId = config.nextSessionId;
      current = nextId == null ? null : await _progress.findSession(nextId);
    }
    // Lo que quedaba pendiente tras el último ejercicio que existe no se
    // llegó a empezar (también si su sesión estaba apuntada pero no creada).
    for (final paper in lastConfig.pending) {
      parts.add(ExamPartResult(paper: paper, status: ExamPartStatus.notTaken));
    }
    return ExamResult(List.unmodifiable(parts));
  }

  Future<ExamPartResult> _part(
    StudySession session,
    ExamSessionConfig config, {
    required bool failedBefore,
  }) async {
    if (!session.isFinished) {
      return ExamPartResult(
        paper: config.paper,
        status: ExamPartStatus.inProgress,
        session: session,
      );
    }
    final questions = await _content.questionsByIds(
      session.packId,
      config.paper.questionIds,
    );
    final summary = SessionSummary.from(
      questions,
      await _progress.sessionAnswers(session.id),
    );
    final scoring = config.paper.scoring;
    return ExamPartResult(
      paper: config.paper,
      status: failedBefore
          ? ExamPartStatus.notCorrected
          : ExamPartStatus.graded,
      session: session,
      summary: summary,
      score: scoring == null
          ? null
          : ScoreCalculator.score(
              scoring,
              ExamTally(
                correct: summary.correct,
                wrong: summary.wrong,
                blank: summary.blank,
              ),
            ),
    );
  }

  static ExamSessionConfig _config(StudySession session) =>
      ExamSessionConfig.fromJson(session.config);
}
