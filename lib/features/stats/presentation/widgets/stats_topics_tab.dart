import 'package:flutter/material.dart';

import '../../../practice/presentation/widgets/summary_sections.dart';
import '../../domain/pack_stats.dart';
import '../stats_texts.dart';

/// Aciertos y cobertura de cada bloque y de cada uno de sus temas.
class StatsTopicsTab extends StatelessWidget {
  const StatsTopicsTab({super.key, required this.stats});

  final PackStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.blocks.isEmpty) {
      return const Center(
        child: Text('No hay preguntas que cumplan estos filtros.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final block in stats.blocks)
          Card(
            child: ExpansionTile(
              // Sin las líneas de arriba y abajo al desplegar: la tarjeta
              // ya marca el borde.
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(block.block.name),
              subtitle: Text(_summary(block.tally, block.coverage)),
              children: [
                for (final topic in block.topics) _TopicRow(topic: topic),
              ],
            ),
          ),
      ],
    );
  }

  static String _summary(AnswerTally tally, Coverage coverage) => [
    if (tally.counted == 0) 'Sin practicar' else topicTallyText(tally),
    'vistas ${coverageText(coverage)}',
  ].join(' · ');
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicStats topic;

  @override
  Widget build(BuildContext context) {
    final coverage = topic.coverage;
    return ListTile(
      title: Text(topicTitle(topic)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(StatsTopicsTab._summary(topic.tally, coverage)),
          const SizedBox(height: 6),
          // La cobertura ya va en el texto: la barra no se lee dos veces.
          ExcludeSemantics(
            child: LinearProgressIndicator(
              value: coverage.practicable == 0
                  ? 0
                  : coverage.seen / coverage.practicable,
            ),
          ),
        ],
      ),
      trailing: topic.isUnpracticed
          ? null
          : Text(
              formatPercent(topic.tally.correctPercent),
              style: Theme.of(context).textTheme.titleSmall,
            ),
    );
  }
}
