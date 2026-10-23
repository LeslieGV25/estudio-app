import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../exam/presentation/exam_texts.dart';
import '../../domain/exam_history.dart';
import '../stats_texts.dart';
import 'chart_colors.dart';

/// Nota de cada ejercicio en los simulacros hechos, con una línea
/// discontinua en la nota mínima.
///
/// En el eje X va el simulacro (en orden), no la fecha: así los ejercicios
/// de un mismo simulacro quedan en la misma vertical y dos simulacros del
/// mismo día no se pisan. La fecha sale en las etiquetas y en el tooltip.
/// Un ejercicio sin nota en un simulacro (no corregido) deja un hueco.
class ExamScoreChart extends StatelessWidget {
  const ExamScoreChart({super.key, required this.history});

  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Simulacros con alguna nota, del más antiguo al más reciente.
    final graded = {
      for (final s in history.series)
        for (final p in s.points) p.firstSessionId,
    };
    final columns = [
      for (final e in history.entries.reversed)
        if (graded.contains(e.firstSessionId)) e,
    ];
    final xOf = {for (final (i, e) in columns.indexed) e.firstSessionId: i};

    final passMarks = {
      for (final s in history.series)
        if (s.passMark case final mark?) mark.toDouble(),
    };
    final values = [
      for (final s in history.series)
        for (final p in s.points) p.score.toDouble(),
      ...passMarks,
    ];
    final minY = math.min(0, values.reduce(math.min)).floorToDouble();
    final maxY = values.reduce(math.max).ceilToDouble();
    final labelEvery = math.max(1, (columns.length / 5).ceil());

    final chart = LineChart(
      LineChartData(
        minX: -0.5,
        maxX: columns.length - 0.5,
        minY: minY,
        maxY: maxY == minY ? minY + 1 : maxY,
        lineBarsData: [
          for (final (i, series) in history.series.indexed)
            _line(series, xOf, columns.length, colors.seriesAt(i), scheme),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            for (final mark in passMarks)
              HorizontalLine(
                y: mark,
                color: scheme.outline,
                strokeWidth: 1,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  labelResolver: (line) =>
                      'Mínimo ${formatScore(_trim(line.y))}',
                ),
              ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
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
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  formatScore(_trim(value)),
                  style: textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (value != i || i < 0 || i >= columns.length) {
                  return const SizedBox();
                }
                // Siempre el último; del resto, uno de cada [labelEvery].
                final isLast = i == columns.length - 1;
                if (!isLast && (columns.length - 1 - i) % labelEvery != 0) {
                  return const SizedBox();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    shortDate(columns[i].startedAt.toLocal()),
                    style: textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            getTooltipItems: (spots) => [
              for (final (i, spot) in spots.indexed)
                LineTooltipItem(
                  _tooltip(columns[spot.x.round()], spot, withDate: i == 0),
                  TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: examChartSemantics(history),
          child: ExcludeSemantics(child: SizedBox(height: 200, child: chart)),
        ),
        if (history.series.length > 1) ...[
          const SizedBox(height: 12),
          ExcludeSemantics(
            child: Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final (i, series) in history.series.indexed)
                  LegendItem(color: colors.seriesAt(i), label: series.name),
              ],
            ),
          ),
        ],
      ],
    );
  }

  LineChartBarData _line(
    ExamScoreSeries series,
    Map<String, int> xOf,
    int columnCount,
    Color color,
    ColorScheme scheme,
  ) {
    final byX = {for (final p in series.points) xOf[p.firstSessionId]!: p};
    return LineChartBarData(
      spots: [
        for (var x = 0; x < columnCount; x++)
          if (byX[x] case final p?)
            FlSpot(x.toDouble(), p.score.toDouble())
          else
            FlSpot.nullSpot,
      ],
      color: color,
      barWidth: 2,
      dotData: FlDotData(
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 2,
          strokeColor: scheme.surfaceContainerLow,
        ),
      ),
    );
  }

  /// «23/10» (solo en la primera línea) y «Ejercicio 1: 5,000».
  String _tooltip(
    ExamHistoryEntry entry,
    LineBarSpot spot, {
    required bool withDate,
  }) {
    final series = history.series[spot.barIndex];
    final point = series.points.firstWhere(
      (p) => p.firstSessionId == entry.firstSessionId,
    );
    final line = '${series.name}: ${formatScore(point.scoreText)}';
    return withDate ? '${shortDate(entry.startedAt.toLocal())}\n$line' : line;
  }

  /// 5.0 → «5», 0.5 → «0.5».
  static String _trim(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
