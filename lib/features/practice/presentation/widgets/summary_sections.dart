import 'package:flutter/material.dart';

import '../../../progress/domain/session_summary.dart';
import '../question_labels.dart';

/// Piezas del resumen de una sesión. Las comparten el resumen de práctica y
/// repaso y el del simulacro (una vez por ejercicio).

String formatPercent(double value) => '${value.round()} %';

/// Tarjeta con el % de aciertos y los aciertos, fallos y en blanco.
class SummaryTotals extends StatelessWidget {
  const SummaryTotals({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              formatPercent(summary.correctPercent),
              style: textTheme.displaySmall?.copyWith(color: colors.primary),
            ),
            const Text('de aciertos'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('Aciertos', summary.correct, summary.correctPercent),
                _Stat('Fallos', summary.wrong, summary.wrongPercent),
                _Stat('En blanco', summary.blank, summary.blankPercent),
              ],
            ),
            if (summary.unanswered > 0) ...[
              const SizedBox(height: 12),
              Text('Sin responder: ${summary.unanswered}'),
            ],
            if (summary.notCounted > 0) ...[
              const SizedBox(height: 4),
              Text(
                'No cuentan: ${summary.notCounted} '
                '(anuladas después de responderlas)',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.count, this.percent);

  final String label;
  final int count;
  final double percent;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('$count', style: Theme.of(context).textTheme.titleLarge),
      Text(label),
      Text(
        formatPercent(percent),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

/// «Por tema»: aciertos, fallos y en blanco de cada tema.
class TopicBreakdownSection extends StatelessWidget {
  const TopicBreakdownSection({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Por tema', style: textTheme.titleMedium),
        for (final topic in summary.byTopic)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Tema ${topic.topicId} · ${topic.topicTitle}'),
            subtitle: Text(
              '${topic.correct} aciertos · ${topic.wrong} fallos · '
              '${topic.blank} en blanco',
            ),
            trailing: Text(
              formatPercent(topic.correct * 100 / topic.total),
              style: textTheme.titleSmall,
            ),
          ),
      ],
    );
  }
}

/// Una pregunta fallada o en blanco: se despliega con la respuesta dada y la
/// correcta.
class MissedQuestionTile extends StatelessWidget {
  const MissedQuestionTile({super.key, required this.item});

  final SummaryItem item;

  @override
  Widget build(BuildContext context) {
    final q = item.question.question;
    final chosen = item.answer?.chosen;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(q.statement, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(questionOrigin(item.question)),
      childrenPadding: const EdgeInsets.only(bottom: 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chosen == null
              ? 'Tu respuesta: en blanco'
              : 'Tu respuesta: ${optionLabel(q, chosen)}',
        ),
        if (q.correctKey case final key?)
          Text('Correcta: ${optionLabel(q, key)}'),
      ],
    );
  }
}
