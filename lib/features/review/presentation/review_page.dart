import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../packs/presentation/packs_providers.dart';
import '../domain/leitner.dart';
import '../domain/review_overview.dart';
import 'review_providers.dart';

/// Repaso de fallos del pack activo: pendientes hoy, reparto por cajas y
/// «Empezar repaso» con el tamaño elegido.
class ReviewPage extends ConsumerWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packId = ref.watch(activePackIdProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Repaso')),
      body: packId == null
          ? const Center(child: Text('Activa un pack para repasar.'))
          : switch (ref.watch(reviewOverviewProvider(packId))) {
              AsyncData(:final value) => _ReviewBody(
                packId: packId,
                overview: value,
              ),
              AsyncError(:final error) => Center(child: Text('Error: $error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
    );
  }
}

/// Tamaños de sesión del selector; `null` = todas.
const reviewSizes = <int?>[10, 20, 50, null];
const defaultReviewSize = 20;

class _ReviewBody extends ConsumerStatefulWidget {
  const _ReviewBody({required this.packId, required this.overview});

  final String packId;
  final ReviewOverview overview;

  @override
  ConsumerState<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends ConsumerState<_ReviewBody> {
  int? _size = defaultReviewSize;
  bool _starting = false;

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final session = await ref.read(startReviewSessionProvider)(
        widget.packId,
        limit: _size,
      );
      if (!mounted) return;
      if (session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No queda nada pendiente')),
        );
      } else {
        context.go(SessionMode.review.sessionPath(session.id));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = widget.overview;
    final pending = overview.due.length;
    final count = _size == null ? pending : pending.clamp(0, _size!);
    final textTheme = Theme.of(context).textTheme;

    if (overview.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay nada que repasar. Las preguntas que falles o dejes '
            'en blanco aparecerán aquí.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PendingCard(overview: overview),
        const SizedBox(height: 24),
        Text('Por cajas', style: textTheme.titleMedium),
        for (final (box, n) in overview.boxCounts.indexed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Caja $box'),
            subtitle: Text(_intervalText(Leitner.intervalDays[box])),
            trailing: Text('$n', style: textTheme.titleMedium),
          ),
        Text(
          'Dominadas (3 aciertos seguidos): ${overview.mastered}',
          style: textTheme.bodyMedium,
        ),
        if (pending > 0) ...[
          const SizedBox(height: 24),
          Text('Preguntas por sesión', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int?>(
            segments: [
              for (final size in reviewSizes)
                ButtonSegment(
                  value: size,
                  label: Text(size == null ? 'Todas' : '$size'),
                ),
            ],
            selected: {_size},
            onSelectionChanged: (s) => setState(() => _size = s.single),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.replay),
            label: Text('Empezar repaso ($count)'),
          ),
        ],
      ],
    );
  }
}

String _intervalText(int days) => switch (days) {
  0 => 'Se repasa el mismo día',
  1 => 'Cada día',
  _ => 'Cada $days días',
};

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.overview});

  final ReviewOverview overview;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final pending = overview.due.length;
    final next = overview.nextDue;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$pending',
              style: textTheme.displaySmall?.copyWith(color: colors.primary),
            ),
            Text(pending == 1 ? 'pendiente hoy' : 'pendientes hoy'),
            if (next != null) ...[
              const SizedBox(height: 8),
              Text('Próximo repaso: ${_shortDate(next)}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// «7/10/2026» en la hora local del dispositivo.
String _shortDate(DateTime instant) {
  final local = instant.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}
