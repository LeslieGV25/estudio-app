/// Convierte instantes en días de calendario para el repaso.
///
/// Los intervalos de Leitner se cuentan en días de la usuaria, no en bloques
/// de 24 h: algo fallado a las 23:59 toca «mañana», igual que algo fallado a
/// las 00:01. Es una interfaz para que los tests no dependan de la zona
/// horaria de la máquina ni del CI (que va en UTC).
abstract interface class ReviewCalendar {
  /// Medianoche (en UTC) del día de [instant] más [plusDays] días.
  DateTime startOfDay(DateTime instant, {int plusDays = 0});
}

/// Días según la zona horaria del dispositivo.
class LocalReviewCalendar implements ReviewCalendar {
  const LocalReviewCalendar();

  @override
  DateTime startOfDay(DateTime instant, {int plusDays = 0}) {
    final local = instant.toLocal();
    // El constructor de DateTime normaliza el día (31 + 1 → día 1 del mes
    // siguiente) y aplica el cambio de hora de esa fecha.
    return DateTime(local.year, local.month, local.day + plusDays).toUtc();
  }
}
