import 'package:flutter/material.dart';

/// Colores de los gráficos, con un tono propio para el modo claro y otro
/// para el oscuro.
///
/// No salen del `ColorScheme` (una sola semilla teal, sin dos tonos que se
/// distingan bien): son una paleta comprobada con daltonismo. Aciertos y
/// fallos van en azul y naranja, no en verde y rojo, porque verde/rojo es
/// justo la pareja que no distingue la deuteranopía (ΔE 4,1; hace falta ≥ 8).
/// Además el color nunca va solo: hay leyenda y textos.
class ChartColors {
  const ChartColors._({
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.series,
  });

  factory ChartColors.of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = ChartColors._(
    correct: Color(0xFF2A78D6),
    wrong: Color(0xFFEB6834),
    blank: Color(0xFF898781),
    series: [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A)],
  );

  static const _dark = ChartColors._(
    correct: Color(0xFF3987E5),
    wrong: Color(0xFFD95926),
    blank: Color(0xFF898781),
    series: [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)],
  );

  final Color correct;
  final Color wrong;

  /// Gris neutro: «en blanco» no es un acierto ni un fallo.
  final Color blank;

  /// Una por ejercicio de simulacro, siempre en este orden (el del pack):
  /// el ej. 1 tiene siempre el mismo color.
  final List<Color> series;

  Color seriesAt(int index) => series[index % series.length];
}

/// Muestra de color + texto de una leyenda.
class LegendItem extends StatelessWidget {
  const LegendItem({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
