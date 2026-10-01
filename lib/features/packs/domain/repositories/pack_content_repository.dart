import '../entities/pack_outline.dart';
import '../entities/study_question.dart';

/// Lectura del contenido de un pack instalado (solo lectura).
///
/// Separada de `PackRepository`, que gestiona la instalación: práctica,
/// simulacro, repaso y estadísticas solo necesitan leer.
abstract interface class PackContentRepository {
  /// Bloques, temas y fuentes del pack, en el orden del fichero.
  Future<PackOutline> outline(String packId);

  /// Todas las preguntas del pack en el orden del fichero, anuladas y
  /// obsoletas incluidas: filtrar es cosa del dominio.
  Future<List<StudyQuestion>> questions(String packId);

  /// Las preguntas con esos [ids], en el mismo orden. Las que ya no existan
  /// (el pack se actualizó y las quitó) se omiten.
  Future<List<StudyQuestion>> questionsByIds(String packId, List<String> ids);
}
