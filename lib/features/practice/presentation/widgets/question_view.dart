import 'package:flutter/material.dart';

import '../../../packs/domain/entities/study_question.dart';
import '../../../progress/domain/entities/answer.dart';
import '../question_labels.dart';
import 'code_block.dart';
import 'context_card.dart';

/// Pregunta completa: origen y tema, contexto (si lo hay), enunciado y
/// opciones. Con [answer] las opciones muestran la corrección y dejan de
/// poder tocarse.
class QuestionView extends StatelessWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.answer,
    required this.onChoose,
  });

  final StudyQuestion question;
  final Answer? answer;

  /// `null` = opciones desactivadas (ya respondida o guardando).
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final caseStudy = question.context;
    final q = question.question;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          questionOrigin(question),
          style: textTheme.labelLarge?.copyWith(color: colors.primary),
        ),
        Text(
          questionTopic(question),
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (caseStudy != null) ...[
          ContextCard(caseStudy),
          const SizedBox(height: 16),
        ],
        Text(q.statement, style: textTheme.titleMedium),
        const SizedBox(height: 16),
        for (final key in q.options.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              letter: key,
              text: q.options[key]!,
              state: _stateOf(key),
              onTap: onChoose == null || answer != null
                  ? null
                  : () => onChoose!(key),
            ),
          ),
      ],
    );
  }

  _OptionState _stateOf(String key) {
    final answer = this.answer;
    if (answer == null) return _OptionState.idle;
    if (key == question.question.correctKey) return _OptionState.correct;
    if (key == answer.chosen) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, border, icon, semantics) = switch (state) {
      _OptionState.correct => (
        colors.primaryContainer,
        colors.primary,
        Icons.check_circle,
        'Respuesta correcta',
      ),
      _OptionState.wrong => (
        colors.errorContainer,
        colors.error,
        Icons.cancel,
        'Tu respuesta, incorrecta',
      ),
      _ => (null, colors.outlineVariant, null, null),
    };
    // Las opciones con saltos de línea (p. ej. consultas SQL) se ven como el
    // código del contexto: monoespaciadas y conservando las líneas.
    final multiline = text.contains('\n');

    return Opacity(
      opacity: state == _OptionState.dimmed ? 0.6 : 1,
      child: Material(
        color: background ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$letter)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: multiline
                      ? CodeBlock(text, selectable: false)
                      : Text(text),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon, color: border, semanticLabel: semantics),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
