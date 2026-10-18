import '../../../../core/domain/session_mode.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../exam_paper.dart';
import '../exam_plan.dart';
import '../exam_session_config.dart';

/// Empieza simulacros y encadena sus ejercicios.
class StartExam {
  const StartExam(this._progress);

  final ProgressRepository _progress;

  /// Sesión del primer ejercicio de [plan]; los demás quedan pendientes en
  /// su configuración. `null` si el plan no tiene preguntas.
  Future<StudySession?> call(String packId, ExamPlan plan) async {
    if (plan.isEmpty) return null;
    final [first, ...rest] = plan.papers;
    return _start(
      packId: packId,
      config: ExamSessionConfig(setup: plan.setup, paper: first, pending: rest),
    );
  }

  /// Sesión del ejercicio que sigue a [previous] (ya entregado). Si ya se
  /// creó, la devuelve; si no, la crea con el id que [previous] tiene
  /// apuntado, así que llamar dos veces no crea dos sesiones. `null` si no
  /// hay más ejercicios.
  Future<StudySession?> next(StudySession previous) async {
    final config = ExamSessionConfig.fromJson(previous.config);
    final nextId = config.nextSessionId;
    if (!previous.isFinished || nextId == null) return null;
    final existing = await _progress.findSession(nextId);
    if (existing != null) return existing;
    final [ExamPaper paper, ...rest] = config.pending;
    return _start(
      id: nextId,
      packId: previous.packId,
      config: ExamSessionConfig(
        setup: config.setup,
        paper: paper,
        pending: rest,
        previousSessionId: previous.id,
      ),
    );
  }

  Future<StudySession> _start({
    String? id,
    required String packId,
    required ExamSessionConfig config,
  }) => _progress.startSession(
    id: id,
    packId: packId,
    mode: SessionMode.exam,
    config: config.toJson(),
  );
}
