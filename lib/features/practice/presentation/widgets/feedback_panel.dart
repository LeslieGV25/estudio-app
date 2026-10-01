import 'package:flutter/material.dart';

import '../../../packs/domain/entities/study_question.dart';
import '../../../progress/domain/entities/answer.dart';
import '../question_labels.dart';

/// Resultado inmediato tras responder: correcta / incorrecta / en blanco,
/// la respuesta buena si no se acertó y la explicación si el pack la trae
/// (si no, no se deja hueco).
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.question,
    required this.answer,
  });

  final StudyQuestion question;
  final Answer answer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final q = question.question;
    final explanation = q.explanation;
    final (title, color) = answer.isCorrect
        ? ('¡Correcto!', colors.primary)
        : answer.isBlank
        ? ('En blanco', colors.onSurfaceVariant)
        : ('Incorrecto', colors.error);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium?.copyWith(color: color)),
            if (!answer.isCorrect && q.correctKey != null) ...[
              const SizedBox(height: 4),
              Text('Respuesta correcta: ${optionLabel(q, q.correctKey!)}'),
            ],
            if (explanation != null && explanation.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Explicación', style: textTheme.labelLarge),
              const SizedBox(height: 4),
              SelectableText(explanation),
            ],
          ],
        ),
      ),
    );
  }
}
