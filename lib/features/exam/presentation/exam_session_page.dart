import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/router/session_routes.dart';
import '../../../core/utils/clock_provider.dart';
import '../../practice/presentation/widgets/question_view.dart';
import '../domain/exam_session_config.dart';
import 'exam_session_controller.dart';
import 'exam_texts.dart';

/// Un ejercicio de simulacro: sin feedback hasta entregar, con temporizador
/// si tiene duración. Se puede ir y volver entre preguntas y cambiar de
/// opción. Entregado, muestra el paso al siguiente ejercicio o el resultado.
class ExamSessionPage extends ConsumerWidget {
  const ExamSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = examSessionControllerProvider(sessionId);
    final session = ref.watch(provider);
    final state = session.value;
    final inProgress =
        state != null && !state.isEmpty && !state.session.isFinished;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state == null ? 'Simulacro' : state.config.paper.name,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (inProgress && state.deadline != null)
            _Countdown(
              deadline: state.deadline!,
              onExpired: () => ref.read(provider.notifier).submit(),
            ),
          if (inProgress)
            TextButton(
              onPressed: () => _confirmSubmit(context, ref, state.config),
              child: const Text('Entregar'),
            ),
        ],
      ),
      body: switch (session) {
        AsyncData(value: null) => const Center(
          child: Text('Este simulacro no existe.'),
        ),
        AsyncData(:final value?) when value.session.isFinished => _Submitted(
          sessionId: sessionId,
          state: value,
        ),
        AsyncData(:final value?) when value.isEmpty => const Center(
          child: Text(
            'Las preguntas de este ejercicio ya no están en el pack.',
          ),
        ),
        AsyncData(:final value?) => _QuestionPane(
          sessionId: sessionId,
          state: value,
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    WidgetRef ref,
    ExamSessionConfig config,
  ) async {
    final blank = config.blankCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Entregar el ejercicio?'),
        content: Text(
          blank == 0
              ? 'Has respondido todas las preguntas.'
              : 'Quedan $blank en blanco. Después ya no se pueden cambiar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entregar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(examSessionControllerProvider(sessionId).notifier)
          .submit();
    }
  }
}

class _QuestionPane extends ConsumerWidget {
  const _QuestionPane({required this.sessionId, required this.state});

  final String sessionId;
  final ExamSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      examSessionControllerProvider(sessionId).notifier,
    );
    final index = state.index;
    final total = state.questions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Navigator(state: state, onTap: controller.goTo),
        const SizedBox(height: 12),
        Text(
          'Pregunta ${index + 1} de $total',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        QuestionView(
          question: state.current,
          answer: null,
          selected: state.currentChoice,
          onChoose: controller.choose,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Anterior',
              onPressed: index == 0 ? null : () => controller.goTo(index - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            const Spacer(),
            if (state.currentChoice != null)
              TextButton(
                onPressed: () => controller.choose(null),
                child: const Text('Dejar en blanco'),
              ),
            const Spacer(),
            IconButton.outlined(
              tooltip: 'Siguiente',
              onPressed: index == total - 1
                  ? null
                  : () => controller.goTo(index + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rejilla con todas las preguntas: marcadas, en blanco y la actual.
class _Navigator extends StatelessWidget {
  const _Navigator({required this.state, required this.onTap});

  final ExamSessionState state;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final config = state.config;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${config.answeredCount} marcadas · ${config.blankCount} en blanco',
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (i, q) in state.questions.indexed)
              _NavCell(
                number: i + 1,
                answered: config.choices.containsKey(q.id),
                current: i == state.index,
                colors: colors,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.number,
    required this.answered,
    required this.current,
    required this.colors,
    required this.onTap,
  });

  final int number;
  final bool answered;
  final bool current;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Pregunta $number, ${answered ? 'marcada' : 'en blanco'}'
        '${current ? ', actual' : ''}',
    excludeSemantics: true,
    child: Material(
      color: answered ? colors.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: current ? colors.primary : colors.outlineVariant,
          width: current ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(child: Text('$number')),
        ),
      ),
    ),
  );
}

/// Tiempo restante; al llegar a cero llama una vez a [onExpired].
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.deadline, required this.onExpired});

  final DateTime deadline;
  final VoidCallback onExpired;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_expired && _remaining() <= Duration.zero) {
      _expired = true;
      widget.onExpired();
    }
  }

  Duration _remaining() =>
      widget.deadline.difference(ref.read(clockProvider)());

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    final colors = Theme.of(context).colorScheme;
    final low = remaining < const Duration(minutes: 5);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        avatar: Icon(
          Icons.timer_outlined,
          size: 18,
          color: low ? colors.error : null,
        ),
        label: Text(
          formatRemaining(remaining),
          semanticsLabel: 'Tiempo restante ${formatRemaining(remaining)}',
          style: TextStyle(
            color: low ? colors.error : null,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Ejercicio entregado: paso al siguiente o al resultado.
class _Submitted extends ConsumerStatefulWidget {
  const _Submitted({required this.sessionId, required this.state});

  final String sessionId;
  final ExamSessionState state;

  @override
  ConsumerState<_Submitted> createState() => _SubmittedState();
}

class _SubmittedState extends ConsumerState<_Submitted> {
  bool _starting = false;

  Future<void> _startNext() async {
    setState(() => _starting = true);
    try {
      final next = await ref
          .read(examSessionControllerProvider(widget.sessionId).notifier)
          .startNext();
      if (!mounted || next == null) return;
      context.go(SessionMode.exam.sessionPath(next.id));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _openResult() =>
      context.go(SessionMode.exam.summaryPath(widget.sessionId));

  @override
  Widget build(BuildContext context) {
    final config = widget.state.config;
    final next = widget.state.hasNextPart ? config.pending.first : null;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.task_alt, size: 48),
            const SizedBox(height: 12),
            Text(
              '${config.paper.name}: entregado',
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (next != null) ...[
              const SizedBox(height: 8),
              const Text(
                'La nota se verá al final, como en el examen real.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(next.name, style: textTheme.titleSmall),
              for (final fact in paperFacts(next)) Text(fact),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _starting ? null : _startNext,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Empezar el siguiente ejercicio'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _openResult,
                child: const Text('Terminar aquí y ver el resultado'),
              ),
            ] else ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _openResult,
                child: const Text('Ver resultado'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
