import '../entities/installed_pack.dart';
import '../entities/pack_document.dart';

/// Acceso al contenido de los packs instalados.
///
/// Solo gestiona CONTENIDO: ninguna operación de esta interfaz puede borrar
/// ni modificar datos de usuario (sesiones, respuestas, repaso, ajustes).
abstract interface class PackRepository {
  /// Packs instalados ordenados por nombre; emite de nuevo con cada cambio.
  Stream<List<InstalledPack>> watchInstalledPacks();

  Future<InstalledPack?> findById(String packId);

  /// Instala [pack] o, si ya hay uno con el mismo id, reemplaza todo su
  /// contenido en una sola transacción (conservando la fecha de instalación).
  ///
  /// No comprueba versiones: decidir si se actualiza es cosa del caso de uso.
  Future<void> save(PackDocument pack);

  /// Borra el contenido del pack. El progreso de la usuaria se conserva y
  /// vuelve a enlazarse si el pack se importa de nuevo (mismos ids).
  Future<void> delete(String packId);
}
