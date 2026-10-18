import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../practice/domain/usecases/start_practice_session.dart';
import '../../practice/presentation/practice_providers.dart';
import '../../practice/presentation/widgets/summary_sections.dart';
import '../domain/usecases/load_exam_result.dart';
import 'exam_providers.dart';
import 'exam_texts.dart';

/// Resultado del simulacro: nota y APTO / NO APTO de cada ejercicio, lo que
/// faltaba para aprobar, la corrección y «Repasar estas».
class ExamSummaryPage extends ConsumerWidget {
  const ExamSummaryPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(examResultProvider(sessionId));
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado del simulacro')),
      body: switch (result) {
        AsyncData(value: null) => const Center(
          child: Text('Este simulacro no existe.'),
        ),
        AsyncData(:final value?) => _ResultBody(result: value),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ResultBody extends ConsumerStatefulWidget {
  const _ResultBody({required this.result});

  final ExamResult result;

  @override
  ConsumerState<_ResultBody> createState() => _ResultBodyState();
}

class _ResultBodyState extends ConsumerState<_ResultBody> {
  bool _starting = false;

  List<String> get _missedIds => [
    for (final part in widget.result.parts)
      for (final item in part.summary?.missed ?? const []) item.question.id,
  ];

  Future<void> _retryMissed() async {
    setState(() => _starting = true);
    try {
      final first = widget.result.firstSession;
      final result = await ref
          .read(startPracticeSessionProvider)
          .retry(first.packId, _missedIds, fromSessionId: first.id);
      if (!mounted) return;
      switch (result) {
        case PracticeStarted(:final session):
          context.go(SessionMode.practice.sessionPath(session.id));
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
    final missed = _missedIds.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final part in widget.result.parts) ...[
          _PartCard(part: part),
          const SizedBox(height: 16),
        ],
        if (missed > 0)
          FilledButton.icon(
            onPressed: _starting ? null : _retryMissed,
            icon: const Icon(Icons.replay),
            label: Text('Repasar estas ($missed)'),
          ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go(SessionMode.exam.basePath),
          child: const Text('Nuevo simulacro'),
        ),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  const _PartCard({required this.part});

  final ExamPartResult part;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final summary = part.summary;
    final score = part.score;
    final graded = part.status == ExamPartStatus.graded;

    final details = summary == null
        ? const <Widget>[]
        : [
            SummaryTotals(summary: summary),
            if (summary.byTopic.isNotEmpty) ...[
              const SizedBox(height: 16),
              TopicBreakdownSection(summary: summary),
            ],
            if (summary.missed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Falladas y en blanco (${summary.missed.length})',
                style: textTheme.titleMedium,
              ),
              for (final item in summary.missed) MissedQuestionTile(item: item),
            ],
          ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(part.paper.name, style: textTheme.titleLarge),
            Text(statusText(part.status)),
            if (graded && score != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      partScoreText(part)!,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                  if (score.passed case final passed?) _Verdict(passed),
                ],
              ),
              if (missingText(score) case final text?) Text(text),
              const SizedBox(height: 4),
              Text(
                '${summary!.counted} valorables · ${valuesText(score)}',
                style: textTheme.bodySmall,
              ),
            ],
            if (part.status == ExamPartStatus.inProgress)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go(
                    SessionMode.exam.sessionPath(part.session!.id),
                  ),
                  child: const Text('Continuar este ejercicio'),
                ),
              ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (graded)
                ...details
              else
                // Sin corregir: la nota no se enseña, pero las respuestas se
                // pueden revisar para aprender.
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Ver tus respuestas'),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: details,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict(this.passed);

  final bool passed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        passed ? Icons.check_circle : Icons.cancel,
        color: passed ? colors.primary : colors.error,
      ),
      label: Text(passed ? 'APTO' : 'NO APTO'),
      backgroundColor: passed ? colors.primaryContainer : colors.errorContainer,
    );
  }
}
