import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/session_mode.dart';
import '../../../../core/router/session_routes.dart';
import '../../../exam/domain/usecases/load_exam_result.dart';
import '../../domain/exam_history.dart';
import '../stats_providers.dart';
import '../stats_texts.dart';
import 'exam_score_chart.dart';

/// Evolución de la nota de cada ejercicio y lista de simulacros. No depende
/// del filtro de estadísticas: un simulacro se puntúa entero.
class StatsExamsTab extends ConsumerWidget {
  const StatsExamsTab({super.key, required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(examHistoryProvider(packId))) {
        AsyncData(:final value) => _History(history: value),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      };
}

class _History extends StatelessWidget {
  const _History({required this.history});

  final ExamHistory history;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (history.entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Aún no has hecho ningún simulacro.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go(SessionMode.exam.basePath),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Hacer un simulacro'),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Notas por ejercicio', style: textTheme.titleMedium),
        const SizedBox(height: 12),
        if (history.series.isEmpty)
          const Text('Todavía no hay ningún ejercicio corregido.')
        else
          ExamScoreChart(history: history),
        const SizedBox(height: 24),
        Text('Simulacros', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final entry in history.entries) _EntryTile(entry: entry),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final ExamHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    // Uno a medias se continúa; los demás abren su resultado.
    final open = entry.result.parts
        .where((p) => p.status == ExamPartStatus.inProgress)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(examEntryTitle(entry)),
        subtitle: Text(
          [
            dateTimeText(entry.startedAt.toLocal()),
            for (final part in entry.result.parts) examPartText(part),
          ].join('\n'),
        ),
        isThreeLine: true,
        trailing: Icon(open == null ? Icons.chevron_right : Icons.play_arrow),
        onTap: () => context.go(
          open == null
              ? SessionMode.exam.summaryPath(entry.firstSessionId)
              : SessionMode.exam.sessionPath(open.session!.id),
        ),
      ),
    );
  }
}
