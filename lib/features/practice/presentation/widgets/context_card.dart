import 'package:flutter/material.dart';

import '../../../packs/domain/entities/pack_document.dart';
import 'code_block.dart';

/// Supuesto práctico (contexto) que se muestra encima de la pregunta.
class ContextCard extends StatelessWidget {
  const ContextCard(this.caseStudy, {super.key});

  final QuestionContext caseStudy;

  @override
  Widget build(BuildContext context) {
    final code = caseStudy.code;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caseStudy.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(caseStudy.statement),
            if (code != null) ...[const SizedBox(height: 12), CodeBlock(code)],
          ],
        ),
      ),
    );
  }
}
