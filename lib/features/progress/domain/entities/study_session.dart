import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/session_mode.dart';

part 'study_session.freezed.dart';

/// Una sesión de práctica, simulacro o repaso.
@freezed
abstract class StudySession with _$StudySession {
  const StudySession._();

  const factory StudySession({
    required String id,
    required String packId,
    required SessionMode mode,

    /// Configuración propia de cada modo (filtros, preguntas elegidas…).
    required Map<String, Object?> config,
    required DateTime startedAt,
    DateTime? finishedAt,

    /// Nota como texto decimal exacto; solo la tiene el simulacro.
    String? score,
  }) = _StudySession;

  bool get isFinished => finishedAt != null;
}
