import 'review_state.dart';

/// Caché del estado de Leitner por pregunta (tabla `review_state`).
///
/// Nunca se calcula aquí: el estado sale siempre de `Leitner.replay` sobre
/// las respuestas, y este repositorio solo lo guarda para poder contar
/// pendientes sin recorrer todos los eventos.
abstract interface class ReviewRepository {
  /// Guarda el estado de cada pregunta de [states]; `null` = la pregunta no
  /// está en el repaso (se quita de la caché). Las demás no se tocan.
  Future<void> saveStates(String packId, Map<String, ReviewState?> states);

  /// Sustituye toda la caché del pack por [states].
  Future<void> replaceAll(String packId, Map<String, ReviewState> states);

  /// Estado de cada pregunta del pack que está en el repaso, por id.
  Future<Map<String, ReviewState>> states(String packId);

  /// Como [states], y vuelve a emitir con cada cambio.
  Stream<Map<String, ReviewState>> watchStates(String packId);
}
