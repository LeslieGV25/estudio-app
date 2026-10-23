import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../packs/presentation/packs_providers.dart';
import '../domain/pack_stats.dart';
import '../domain/stats_filter.dart';
import 'stats_providers.dart';
import 'stats_texts.dart';
import 'widgets/stats_exams_tab.dart';
import 'widgets/stats_overview_tab.dart';
import 'widgets/stats_topics_tab.dart';

/// Estadísticas del pack activo en tres pestañas: resumen (global, días,
/// temas débiles y sin practicar), por tema y simulacros.
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packId = ref.watch(activePackIdProvider).value;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estadísticas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Temas'),
              Tab(text: 'Simulacros'),
            ],
          ),
        ),
        body: packId == null
            ? const Center(child: Text('Activa un pack para ver tus datos.'))
            : TabBarView(
                children: [
                  _WithStats(
                    packId: packId,
                    builder: (stats) => StatsOverviewTab(stats: stats),
                  ),
                  _WithStats(
                    packId: packId,
                    builder: (stats) => StatsTopicsTab(stats: stats),
                  ),
                  StatsExamsTab(packId: packId),
                ],
              ),
      ),
    );
  }
}

/// Carga las estadísticas con el filtro actual y las pinta debajo del
/// resumen del filtro (común a «Resumen» y «Temas»).
class _WithStats extends ConsumerWidget {
  const _WithStats({required this.packId, required this.builder});

  final String packId;
  final Widget Function(PackStats stats) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(packStatsProvider(packId));
    return Column(
      children: [
        const _FilterBar(),
        Expanded(
          child: switch (stats) {
            // Al cambiar el filtro se siguen viendo los datos anteriores
            // mientras se recalculan.
            AsyncValue(:final value?) => builder(value),
            AsyncError(:final error) => Center(child: Text('Error: $error')),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterControllerProvider);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        leading: const Icon(Icons.filter_list),
        title: Text(filterSummary(filter)),
        trailing: const Text('Cambiar'),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => const _FilterSheet(),
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterControllerProvider);
    final controller = ref.read(statsFilterControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Respuestas de', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final mode in SessionMode.values)
                  FilterChip(
                    label: Text(mode.label),
                    selected: filter.modes.contains(mode),
                    // Siempre queda al menos un modo marcado.
                    onSelected:
                        filter.modes.length == 1 && filter.modes.contains(mode)
                        ? null
                        : (_) => controller.toggleMode(mode),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Fuentes', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<SourceFilter>(
              segments: [
                for (final s in SourceFilter.values)
                  ButtonSegment(value: s, label: Text(sourceFilterLabel(s))),
              ],
              selected: {filter.sources},
              onSelectionChanged: (s) => controller.setSources(s.single),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir obsoletas'),
              value: filter.includeObsolete,
              onChanged: controller.setIncludeObsolete,
            ),
          ],
        ),
      ),
    );
  }
}
