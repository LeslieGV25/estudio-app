import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'practice_session_controller.dart';
import 'widgets/feedback_panel.dart';
import 'widgets/question_view.dart';

/// Una pregunta cada vez, con feedback inmediato.
class PracticeSessionPage extends ConsumerWidget {
  const PracticeSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = practiceSessionControllerProvider(sessionId);
    final session = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    void openSummary() => context.go('/practice/summary/$sessionId');

    Future<void> finishEarly() async {
      await controller.finish();
      openSummary();
    }

    Future<void> next() async {
      if (await controller.next()) openSummary();
    }

    final state = session.value;
    final canFinish = state != null && !state.session.isFinished;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state == null || state.isEmpty
              ? 'Práctica'
              : 'Pregunta ${state.index + 1} de ${state.questions.length}',
        ),
        actions: [
          if (canFinish)
            TextButton(onPressed: finishEarly, child: const Text('Terminar')),
        ],
        bottom: state == null || state.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: state.answers.length / state.questions.length,
                ),
              ),
      ),
      body: switch (session) {
        AsyncData(value: null) => const Center(
          child: Text('Esta sesión no existe.'),
        ),
        AsyncData(:final value?) when value.session.isFinished => _Ended(
          message: 'Esta sesión ya terminó.',
          onSummary: openSummary,
        ),
        AsyncData(:final value?) when value.isEmpty => _Ended(
          message: 'No quedan preguntas: el pack se actualizó y las anuló.',
          onSummary: openSummary,
        ),
        AsyncData(:final value?) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            QuestionView(
              question: value.current,
              answer: value.currentAnswer,
              onChoose: controller.answer,
            ),
            const SizedBox(height: 8),
            if (value.currentAnswer case final answer?) ...[
              FeedbackPanel(question: value.current, answer: answer),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: next,
                child: Text(
                  value.nextIndex == null ? 'Ver resumen' : 'Siguiente',
                ),
              ),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => controller.answer(null),
                  child: const Text('Saltar (en blanco)'),
                ),
              ),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Ended extends StatelessWidget {
  const _Ended({required this.message, required this.onSummary});

  final String message;
  final VoidCallback onSummary;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: onSummary, child: const Text('Ver resumen')),
      ],
    ),
  );
}
