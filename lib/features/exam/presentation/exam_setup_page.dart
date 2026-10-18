import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../packs/domain/entities/pack_document.dart';
import '../../packs/presentation/packs_providers.dart';
import '../../practice/presentation/practice_providers.dart';
import '../domain/exam_plan.dart';
import '../domain/exam_setup.dart';
import 'exam_providers.dart';
import 'exam_texts.dart';

/// Elegir simulacro: examen real o aleatorio, completo o un ejercicio, con
/// lo que tendrá cada ejercicio antes de empezar.
class ExamSetupPage extends ConsumerWidget {
  const ExamSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packId = ref.watch(activePackIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulacro')),
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
    final rules = ref.watch(examRulesProvider(packId));
    final outline = ref.watch(packOutlineProvider(packId));
    return switch ((rules, outline)) {
      (AsyncData(value: final r), _) when r.exercises.isEmpty => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este pack no trae reglas de simulacro.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      (AsyncData(value: final r), AsyncData(value: final o)) => Column(
        children: [
          Expanded(
            child: _Options(
              packId: packId,
              rules: r,
              sources: ExamPlan.realExamSources(o, r),
            ),
          ),
          _StartBar(packId: packId),
        ],
      ),
      (AsyncError(:final error), _) ||
      (_, AsyncError(:final error)) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Options extends ConsumerWidget {
  const _Options({
    required this.packId,
    required this.rules,
    required this.sources,
  });

  final String packId;
  final ExamRules rules;
  final List<Source> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(examSetupControllerProvider);
    final controller = ref.read(examSetupControllerProvider.notifier);
    // El examen elegido de verdad (por defecto, el primero) sale del plan.
    final sourceId = ref.watch(examPlanProvider(packId)).value?.setup.sourceId;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rules.note case final note?) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(note)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text('Preguntas', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ExamKind>(
          segments: [
            const ButtonSegment(
              value: ExamKind.random,
              label: Text('Aleatorio'),
              icon: Icon(Icons.shuffle),
            ),
            if (sources.isNotEmpty)
              const ButtonSegment(
                value: ExamKind.realExam,
                label: Text('Examen real'),
                icon: Icon(Icons.description_outlined),
              ),
          ],
          selected: {setup.kind},
          onSelectionChanged: (s) => controller.setKind(s.single),
        ),
        const SizedBox(height: 8),
        if (setup.kind == ExamKind.realExam)
          RadioGroup<String>(
            groupValue: sourceId,
            onChanged: (id) {
              if (id != null) controller.setSource(id);
            },
            child: Column(
              children: [
                for (final s in sources)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: s.id,
                    title: Text(s.name),
                    subtitle: s.isOfficial
                        ? null
                        : const Text('Respuestas no oficiales'),
                  ),
              ],
            ),
          )
        else ...[
          const Text(
            'Preguntas al azar de todos los exámenes de cada ejercicio; las '
            'de reserva entran como normales.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo preguntas oficiales'),
            subtitle: const Text('Con la respuesta de una plantilla oficial'),
            value: setup.onlyOfficial,
            onChanged: controller.setOnlyOfficial,
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Incluir obsoletas'),
          subtitle: const Text('Basadas en normativa o tecnología superada'),
          value: setup.includeObsolete,
          onChanged: controller.setIncludeObsolete,
        ),
        const SizedBox(height: 8),
        Text('Ejercicios', style: textTheme.titleMedium),
        RadioGroup<String>(
          // RadioGroup no admite null como valor: '' = simulacro completo.
          groupValue: setup.exerciseId ?? '',
          onChanged: (id) =>
              controller.setExercise(id == null || id.isEmpty ? null : id),
          child: Column(
            children: [
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: '',
                title: const Text('Simulacro completo'),
                subtitle: Text(
                  rules.exercises.map((e) => e.name).join(' y después '),
                ),
              ),
              for (final e in rules.exercises)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: e.id,
                  title: Text('Solo ${e.name.toLowerCase()}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lo que tendrá cada ejercicio y el botón «Empezar».
class _StartBar extends ConsumerStatefulWidget {
  const _StartBar({required this.packId});

  final String packId;

  @override
  ConsumerState<_StartBar> createState() => _StartBarState();
}

class _StartBarState extends ConsumerState<_StartBar> {
  bool _starting = false;

  Future<void> _start(ExamPlan plan) async {
    setState(() => _starting = true);
    try {
      final session = await ref.read(startExamProvider)(widget.packId, plan);
      if (!mounted || session == null) return;
      context.go(SessionMode.exam.sessionPath(session.id));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(examPlanProvider(widget.packId)).value;
    final textTheme = Theme.of(context).textTheme;

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
              if (plan == null)
                const Text('Calculando…')
              else if (plan.isEmpty)
                const Text('No hay preguntas para este simulacro.')
              else
                for (final paper in plan.papers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paper.name, style: textTheme.titleSmall),
                        for (final fact in paperFacts(paper)) Text(fact),
                      ],
                    ),
                  ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed: plan == null || plan.isEmpty || _starting
                    ? null
                    : () => _start(plan),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Empezar simulacro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
