import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme_mode_controller.dart';

/// Pantalla provisional de Fase 0. Se sustituirá por la lista de packs
/// en Fase 1.
class HomePlaceholderPage extends ConsumerWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estudio por packs'),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(),
          ),
        ],
      ),
      body: const Center(child: Text('Estudio por packs')),
    );
  }
}
