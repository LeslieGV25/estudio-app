import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;

import '../../packs/domain/entities/pack_document.dart';
import '../../packs/domain/entities/pack_outline.dart';
import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../packs/presentation/packs_providers.dart';
import '../domain/practice_filter.dart';
import '../domain/practice_plan.dart';
import '../domain/usecases/start_practice_session.dart';
import 'practice_providers.dart';
import 'practice_setup_controller.dart';

/// Opciones de «Nº de preguntas»; `null` = todas.
const _questionCounts = <int?>[10, 20, 50, null];

/// Elegir qué practicar en el pack activo: temas o bloques, fuentes,
/// oficiales/obsoletas y nº de preguntas, con el recuento en vivo.
class PracticeSetupPage extends ConsumerWidget {
  const PracticeSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packId = ref.watch(activePackIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Practicar')),
      body: switch (packId) {
        AsyncData(value: final id?) => _SetupForm(packId: id),
        AsyncData() => const Center(child: Text('No hay ningún pack activo.')),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SetupForm extends ConsumerWidget {
  const _SetupForm({required this.packId});

  final String packId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(packOutlineProvider(packId));
    return switch (outline) {
      AsyncData(:final value) => Column(
        children: [
          Expanded(child: _FilterList(outline: value)),
          _StartBar(packId: packId),
        ],
      ),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _FilterList extends ConsumerWidget {
  const _FilterList({required this.outline});

  final PackOutline outline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(practiceFilterControllerProvider);
    final controller = ref.read(practiceFilterControllerProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Temario', style: textTheme.titleMedium),
        const Text('Sin marcar nada se usan todos los temas.'),
        const SizedBox(height: 8),
        for (final block in outline.blocks)
          _BlockTile(
            block: block,
            topics: [
              for (final t in outline.topics)
                if (t.blockId == block.id) t,
            ],
            filter: filter,
          ),
        const SizedBox(height: 16),
        Text('Fuentes', style: textTheme.titleMedium),
        const Text('Sin marcar ninguna se usan todas.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final source in outline.sources)
              FilterChip(
                label: Text(source.name),
                selected: filter.sourceIds.contains(source.id),
                onSelected: (_) => controller.toggleSource(source.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Solo preguntas oficiales'),
          subtitle: const Text('Con la respuesta de una plantilla oficial'),
          value: filter.onlyOfficial,
          onChanged: controller.setOnlyOfficial,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir obsoletas'),
          subtitle: const Text('Basadas en normativa o tecnología superada'),
          value: filter.includeObsolete,
          onChanged: controller.setIncludeObsolete,
        ),
        const SizedBox(height: 8),
        Text('Nº de preguntas', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          // SegmentedButton no admite null como valor: 0 = «Todas».
          segments: [
            for (final n in _questionCounts)
              ButtonSegment(
                value: n ?? 0,
                label: Text(n?.toString() ?? 'Todas'),
              ),
          ],
          selected: {filter.questionCount ?? 0},
          onSelectionChanged: (selection) {
            final n = selection.single;
            controller.setQuestionCount(n == 0 ? null : n);
          },
        ),
      ],
    );
  }
}

class _BlockTile extends ConsumerWidget {
  const _BlockTile({
    required this.block,
    required this.topics,
    required this.filter,
  });

  final Block block;
  final List<Topic> topics;
  final PracticeFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(practiceFilterControllerProvider.notifier);
    final blockSelected = filter.blockIds.contains(block.id);
    final chosenTopics = topics.where((t) => filter.topicIds.contains(t.id));

    return Card(
      child: ExpansionTile(
        leading: Checkbox(
          value: blockSelected,
          semanticLabel: 'Todo el bloque ${block.name}',
          onChanged: (_) => controller.toggleBlock(block.id),
        ),
        title: Text(block.name),
        subtitle: Text(
          blockSelected
              ? 'Todo el bloque'
              : chosenTopics.isEmpty
              ? '${topics.length} temas'
              : '${chosenTopics.length} de ${topics.length} temas',
        ),
        children: [
          for (final topic in topics)
            CheckboxListTile(
              // Con el bloque entero marcado, sus temas ya están dentro.
              value: blockSelected || filter.topicIds.contains(topic.id),
              onChanged: blockSelected
                  ? null
                  : (_) => controller.toggleTopic(topic.id),
              title: Text('Tema ${topic.id}. ${topic.title}'),
              dense: true,
            ),
        ],
      ),
    );
  }
}

/// Recuento en vivo, aviso de sesión más corta y botón «Empezar».
class _StartBar extends ConsumerStatefulWidget {
  const _StartBar({required this.packId});

  final String packId;

  @override
  ConsumerState<_StartBar> createState() => _StartBarState();
}

class _StartBarState extends ConsumerState<_StartBar> {
  bool _starting = false;

  Future<void> _start(PracticePlan plan) async {
    setState(() => _starting = true);
    try {
      final result = await ref.read(startPracticeSessionProvider)(
        widget.packId,
        plan,
      );
      if (!mounted) return;
      switch (result) {
        case PracticeStarted(:final session):
          context.go(SessionMode.practice.sessionPath(session.id));
        case NoQuestionsMatch():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ninguna pregunta cumple los filtros'),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(practicePlanProvider(widget.packId)).value;
    final notice = plan == null ? null : practicePlanNotice(plan);
    final colors = Theme.of(context).colorScheme;

    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (plan) {
                null => 'Calculando…',
                PracticePlan(isEmpty: true) =>
                  'Ninguna pregunta cumple estos filtros.',
                PracticePlan(available: 1) => '1 pregunta disponible',
                PracticePlan(:final available) =>
                  '$available preguntas disponibles',
              }),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colors.tertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text(notice)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: plan == null || plan.isEmpty || _starting
                    ? null
                    : () => _start(plan),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  plan == null || plan.isEmpty
                      ? 'Empezar'
                      : 'Empezar (${plan.count})',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
