import 'dart:math';

import '../../../../core/domain/session_mode.dart';
import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/entities/study_session.dart';
import '../../../progress/domain/progress_repository.dart';
import '../grading.dart';
import '../practice_filter.dart';
import '../practice_session_config.dart';
import '../question_order.dart';

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

/// Elige las preguntas de una sesión de práctica y la crea.
class StartPracticeSession {
  StartPracticeSession(this._content, this._progress, {Random? random})
    : _random = random ?? Random();

  final PackContentRepository _content;
  final ProgressRepository _progress;
  final Random _random;

  /// Sesión nueva con las preguntas de [packId] que cumplen [filter],
  /// barajadas por grupos de contexto (ver [practiceOrder]).
  Future<PracticeStart> call(String packId, PracticeFilter filter) async {
    final candidates = (await _content.questions(packId))
        .where(filter.matches)
        .toList();
    final ordered = practiceOrder(
      candidates,
      limit: filter.questionCount,
      random: _random,
    );
    return _start(
      packId,
      PracticeSessionConfig(
        questionIds: [for (final q in ordered) q.id],
        filter: filter,
      ),
    );
  }

  /// «Repasar estas»: sesión nueva con [questionIds] en el mismo orden.
  /// Se omiten las que ya no existan en el pack y las que no se pueden
  /// corregir (anuladas sin respuesta provisional, p. ej. porque una
  /// actualización del pack anuló una pregunta que se había fallado).
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
            if (practiceKey(q.question) != null) q.id,
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
