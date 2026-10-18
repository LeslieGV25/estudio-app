import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../progress/domain/entities/study_session.dart';
import '../../progress/domain/session_summary.dart';
import '../domain/usecases/start_practice_session.dart';
import 'practice_providers.dart';
import 'widgets/summary_sections.dart';

/// Resumen final: porcentajes, desglose por tema y lista de falladas con
/// «Repasar estas». Se reconstruye desde la base de datos. Lo usan práctica
/// y repaso; «Repasar estas» siempre crea una práctica.
class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({
    super.key,
    required this.sessionId,
    required this.mode,
  });

  final String sessionId;
  final SessionMode mode;

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
          mode: mode,
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SummaryBody extends ConsumerStatefulWidget {
  const _SummaryBody({
    required this.session,
    required this.summary,
    required this.mode,
  });

  final StudySession session;
  final SessionSummary summary;
  final SessionMode mode;

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
    final summary = widget.summary;
    final textTheme = Theme.of(context).textTheme;
    final missed = summary.missed;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SummaryTotals(summary: summary),
        if (summary.byTopic.isNotEmpty) ...[
          const SizedBox(height: 24),
          TopicBreakdownSection(summary: summary),
        ],
        if (missed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Falladas y en blanco (${missed.length})',
            style: textTheme.titleMedium,
          ),
          for (final item in missed) MissedQuestionTile(item: item),
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
          onPressed: () => context.go(widget.mode.basePath),
          child: Text(switch (widget.mode) {
            SessionMode.review => 'Volver al repaso',
            _ => 'Nueva práctica',
          }),
        ),
      ],
    );
  }
}
