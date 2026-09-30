import 'package:flutter/material.dart';

import '../domain/usecases/import_pack.dart';

/// Texto exacto acordado para confirmar el borrado de un pack.
const deletePackMessage =
    'Se eliminará el pack. Tu progreso se conserva y lo recuperarás si '
    'vuelves a importarlo.';

/// `true` si la usuaria confirma el borrado.
Future<bool> confirmDeletePack(BuildContext context, String packName) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Borrar «$packName»?'),
        content: const Text(deletePackMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    ) ??
    false;

/// `true` si la usuaria acepta reemplazar un pack por la misma versión o
/// por una anterior.
Future<bool> confirmReplacePack(
  BuildContext context,
  ImportNeedsConfirmation outcome,
) async {
  final info = outcome.pack.info;
  final which = outcome.isDowngrade
      ? 'una versión anterior (${info.version})'
      : 'la misma versión';
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ya tienes este pack'),
          content: Text(
            'Tienes instalada la versión ${outcome.installedVersion} de '
            '«${info.name}» y el fichero trae $which. '
            '¿Quieres reemplazarla? Tu progreso se conserva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      ) ??
      false;
}

/// Lista los errores del validador (como mucho [maxShown]).
Future<void> showInvalidPackDialog(
  BuildContext context,
  List<String> errors, {
  int maxShown = 20,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('El fichero no es un pack válido'),
    content: SizedBox(
      width: double.maxFinite,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final error in errors.take(maxShown))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SelectableText('• $error'),
            ),
          if (errors.length > maxShown)
            Text('…y ${errors.length - maxShown} error(es) más.'),
        ],
      ),
    ),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Entendido'),
      ),
    ],
  ),
);
