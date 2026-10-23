import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/pack_stats.dart';
import '../stats_texts.dart';
import 'chart_colors.dart';

/// Respuestas de cada día (barras apiladas: aciertos, fallos y en blanco).
///
/// Para lectores de pantalla el gráfico se sustituye por un resumen en
/// texto ([daysSemantics]).
class DailyChart extends StatelessWidget {
  const DailyChart({super.key, required this.days});

  /// Del más antiguo a hoy.
  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxCount = days.fold(
      0,
      (m, d) => d.tally.counted > m ? d.tally.counted : m,
    );
    final interval = _gridInterval(maxCount);

    final chart = BarChart(
      BarChartData(
        maxY: (maxCount / interval).ceil() * interval.toDouble(),
        alignment: BarChartAlignment.spaceBetween,
        barGroups: [
          for (final (i, day) in days.indexed) _group(i, day, colors, scheme),
        ],
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval.toDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: scheme.outlineVariant, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: BorderSide(color: scheme.outline)),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: interval.toDouble(),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                // Una etiqueta por semana, contando desde hoy.
                if ((days.length - 1 - i) % 7 != 0) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  // La de hoy está en el borde derecho: que no se salga.
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    shortDate(days[i].day.toLocal()),
                    style: textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 200,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = days[group.x];
              return BarTooltipItem(
                '${shortDate(day.day.toLocal())}\n${_tooltip(day.tally)}',
                TextStyle(color: scheme.onInverseSurface, fontSize: 12),
              );
            },
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: daysSemantics(days),
          child: ExcludeSemantics(child: SizedBox(height: 180, child: chart)),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              LegendItem(color: colors.correct, label: 'Aciertos'),
              LegendItem(color: colors.wrong, label: 'Fallos'),
              LegendItem(color: colors.blank, label: 'En blanco'),
            ],
          ),
        ),
      ],
    );
  }

  BarChartGroupData _group(
    int x,
    DayStats day,
    ChartColors colors,
    ColorScheme scheme,
  ) {
    final t = day.tally;
    // Un borde del color de la superficie separa los tramos de la barra.
    final gap = BorderSide(color: scheme.surfaceContainerLow, width: 1);
    final correctTop = t.correct.toDouble();
    final wrongTop = correctTop + t.wrong;
    final blankTop = wrongTop + t.blank;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: blankTop,
          width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          rodStackItems: [
            if (t.correct > 0)
              BarChartRodStackItem(
                0,
                correctTop,
                colors.correct,
                borderSide: gap,
              ),
            if (t.wrong > 0)
              BarChartRodStackItem(
                correctTop,
                wrongTop,
                colors.wrong,
                borderSide: gap,
              ),
            if (t.blank > 0)
              BarChartRodStackItem(
                wrongTop,
                blankTop,
                colors.blank,
                borderSide: gap,
              ),
          ],
        ),
      ],
    );
  }

  static String _tooltip(AnswerTally t) => t.counted == 0
      ? 'Sin respuestas'
      : '${t.correct} aciertos · ${t.wrong} fallos · ${t.blank} en blanco';

  /// Separación de las líneas de la rejilla: unas 4 líneas como mucho.
  static int _gridInterval(int maxCount) {
    for (final step in const [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500]) {
      if (maxCount <= step * 4) return step;
    }
    return 1000;
  }
}
