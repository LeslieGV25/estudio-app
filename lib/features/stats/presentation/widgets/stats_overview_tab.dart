import 'package:flutter/material.dart';

import '../../../practice/presentation/widgets/summary_sections.dart';
import '../../domain/pack_stats.dart';
import '../../domain/stats_calculator.dart';
import '../stats_texts.dart';
import 'daily_chart.dart';
import 'topic_to_practice.dart';

/// Global, últimos 30 días, temas débiles y temas sin practicar.
class StatsOverviewTab extends StatelessWidget {
  const StatsOverviewTab({super.key, required this.stats});

  final PackStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (stats.tally.counted == 0 && stats.unpracticedTopics.isEmpty) {
      return const Center(
        child: Text('No hay preguntas que cumplan estos filtros.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Totals(stats: stats),
        const SizedBox(height: 24),
        Text(
          'Últimos ${StatsCalculator.windowDays} días',
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        DailyChart(days: stats.days),
        const SizedBox(height: 24),
        Text('Temas débiles', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (stats.weakTopics.isEmpty)
          Text(noWeakTopicsText)
        else ...[
          Text(
            'Por debajo del ${StatsCalculator.weakFloorPercent} % o de tu '
            'media, con al menos ${StatsCalculator.weakMinAnswers} '
            'respuestas.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final topic in stats.weakTopics)
            TopicToPractice(topic: topic, detail: topicTallyText(topic.tally)),
        ],
        const SizedBox(height: 24),
        Text('Temas sin practicar', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (stats.unpracticedTopics.isEmpty)
          const Text('Has practicado todos los temas.')
        else
          for (final topic in stats.unpracticedTopics)
            TopicToPractice(
              topic: topic,
              detail:
                  '${topic.coverage.practicable} '
                  '${topic.coverage.practicable == 1 ? 'pregunta' : 'preguntas'}',
            ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final PackStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final tally = stats.tally;
    if (tally.counted == 0) {
      // Un «0 %» grande diría que todo está mal, cuando no hay datos.
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Todavía no hay respuestas con estos filtros.'),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              formatPercent(tally.correctPercent),
              style: textTheme.displaySmall?.copyWith(color: colors.primary),
            ),
            Text('de aciertos en ${answersText(tally.counted)}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Figure('Aciertos', '${tally.correct}'),
                _Figure('Fallos', '${tally.wrong}'),
                _Figure('En blanco', '${tally.blank}'),
              ],
            ),
            const Divider(height: 32),
            _Line('Preguntas vistas', coverageText(stats.coverage)),
            _Line('Dominadas en el repaso', '${stats.mastered}'),
            _Line('Días con estudio', '${stats.studyDays}'),
            _Line(
              'Tiempo medio por pregunta',
              averageTimeText(tally.averageTime),
            ),
            if (stats.notCounted > 0) ...[
              const SizedBox(height: 8),
              Text(
                'No cuentan: ${answersText(stats.notCounted)} a preguntas '
                'anuladas o que ya no están en el pack.',
                style: textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label),
    ],
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: Theme.of(context).textTheme.titleSmall),
      ],
    ),
  );
}
