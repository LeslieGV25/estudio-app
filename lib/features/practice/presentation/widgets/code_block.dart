import 'package:flutter/material.dart';

/// Estilo monoespaciado común a código de supuestos y opciones multilínea.
TextStyle monospaceStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodyMedium!
    .copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
      height: 1.4,
    );

/// Texto en fuente monoespaciada que conserva saltos de línea y espacios,
/// con scroll horizontal en lugar de partir las líneas largas.
///
/// [selectable] es `true` para el código del contexto (se puede copiar) y
/// `false` dentro de una opción, porque un texto seleccionable se quedaría
/// los toques y no dejaría elegir la opción.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.text, {super.key, this.selectable = true});

  final String text;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final style = monospaceStyle(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: selectable
            ? SelectableText(text, style: style)
            : Text(text, style: style, softWrap: false),
      ),
    );
  }
}
