/// Preferencias de la usuaria.
///
/// Métodos con nombre en vez de un `get(key)` genérico: el dominio no sabe
/// que por debajo hay una tabla clave-valor.
abstract interface class SettingsRepository {
  Stream<String?> watchActivePackId();

  Future<String?> getActivePackId();

  /// `null` = ningún pack activo.
  Future<void> setActivePackId(String? packId);

  /// Si el pack incluido en la app ya se importó alguna vez. Sirve para no
  /// volver a instalarlo si la usuaria lo borra.
  Future<bool> isBundledPackSeeded();

  Future<void> markBundledPackSeeded();
}
