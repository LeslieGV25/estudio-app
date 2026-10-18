import '../../../core/domain/session_mode.dart';
import 'entities/answer.dart';
import 'entities/study_session.dart';

/// Respuesta aún sin guardar (el pack y la hora los pone el repositorio).
typedef NewAnswer = ({
  String questionId,
  String? chosen,
  bool isCorrect,
  int timeMs,
});

/// Datos de progreso de la usuaria: sesiones y respuestas.
///
/// Las respuestas son eventos de solo inserción; estadísticas y repaso se
/// derivan de ellas. Hoy se implementa con Drift; con servidor, una
/// implementación remota subiría los eventos nuevos.
abstract interface class ProgressRepository {
  /// Con [id] se usa ese id (UUID generado de antemano, p. ej. el que un
  /// ejercicio de simulacro ya apunta como siguiente); si no, uno nuevo.
  Future<StudySession> startSession({
    String? id,
    required String packId,
    required SessionMode mode,
    required Map<String, Object?> config,
  });

  /// `null` si no existe o está borrada.
  Future<StudySession?> findSession(String sessionId);

  /// Sustituye la configuración de una sesión sin terminar (el borrador del
  /// simulacro). Lanza [StateError] si no existe o ya terminó.
  Future<void> updateSessionConfig(
    String sessionId,
    Map<String, Object?> config,
  );

  /// Marca la sesión como terminada. Si ya lo estaba, no cambia nada.
  Future<void> finishSession(String sessionId, {String? score});

  /// Entrega de una vez (simulacro): guarda [answers], sustituye la
  /// configuración por [config] y termina la sesión con [score], todo en
  /// una transacción. Lanza [StateError] si no existe o ya terminó.
  Future<void> submitSession(
    String sessionId, {
    required List<NewAnswer> answers,
    required Map<String, Object?> config,
    String? score,
  });

  /// Guarda una respuesta de la sesión [sessionId] (el pack se toma de la
  /// sesión). Lanza [StateError] si la sesión no existe o ya terminó.
  Future<Answer> recordAnswer({
    required String sessionId,
    required String questionId,
    required String? chosen,
    required bool isCorrect,
    required int timeMs,
  });

  /// Respuestas de la sesión en el orden en que se dieron.
  Future<List<Answer>> sessionAnswers(String sessionId);

  Stream<List<Answer>> watchSessionAnswers(String sessionId);

  /// Respuestas del pack [packId] dadas en sesiones de [modes] no borradas,
  /// en orden cronológico. Con [questionIds], solo las de esas preguntas.
  Future<List<Answer>> packAnswers(
    String packId, {
    required Set<SessionMode> modes,
    Iterable<String>? questionIds,
  });
}
