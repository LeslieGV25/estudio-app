import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../progress/domain/entities/study_session.dart';
import '../../progress/domain/session_summary.dart';
import '../domain/usecases/start_practice_session.dart';
import 'practice_providers.dart';
import 'question_labels.dart';

/// Resumen final: porcentajes, desglose por tema y lista de falladas con
/// «Repasar estas». Se reconstruye desde la base de datos.
class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(practiceSummaryProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: switch (result) {
        AsyncData(value: null) => const Center(
          child: Text('Esta sesión no existe.'),
        ),
        AsyncData(value: (:final session, :final summary)?) => _SummaryBody(
          session: session,
          summary: summary,
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

String _percent(double value) => '${value.round()} %';

class _SummaryBody extends ConsumerStatefulWidget {
  const _SummaryBody({required this.session, required this.summary});

  final StudySession session;
  final SessionSummary summary;

  @override
  ConsumerState<_SummaryBody> createState() => _SummaryBodyState();
}

class _SummaryBodyState extends ConsumerState<_SummaryBody> {
  bool _starting = false;

  Future<void> _retryMissed() async {
    setState(() => _starting = true);
    try {
      final result = await ref.read(startPracticeSessionProvider).retry(
        widget.session.packId,
        [for (final item in widget.summary.missed) item.question.id],
        fromSessionId: widget.session.id,
      );
      if (!mounted) return;
      switch (result) {
        case PracticeStarted(:final session):
          context.go('/practice/session/${session.id}');
        case NoQuestionsMatch():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Esas preguntas ya no están en el pack'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final textTheme = Theme.of(context).textTheme;
    final missed = summary.missed;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Totals(summary: summary),
        if (summary.byTopic.isNotEmpty) ...[
          const SizedBox(height: 24),
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
                _percent(topic.correct * 100 / topic.total),
                style: textTheme.titleSmall,
              ),
            ),
        ],
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Falladas y en blanco (${missed.length})',
            style: textTheme.titleMedium,
          ),
          for (final item in missed) _MissedTile(item: item),
        ],
        const SizedBox(height: 24),
        if (missed.isNotEmpty)
          FilledButton.icon(
            onPressed: _starting ? null : _retryMissed,
            icon: const Icon(Icons.replay),
            label: Text('Repasar estas (${missed.length})'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/practice'),
          child: const Text('Nueva práctica'),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

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
              _percent(summary.correctPercent),
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
      Text(_percent(percent), style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MissedTile extends StatelessWidget {
  const _MissedTile({required this.item});

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
