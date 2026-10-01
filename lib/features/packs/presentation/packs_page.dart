import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_mode_controller.dart';
import '../domain/entities/installed_pack.dart';
import '../domain/usecases/import_pack.dart';
import 'packs_controller.dart';
import 'packs_dialogs.dart';
import 'packs_providers.dart';

/// Pantalla de inicio: lista de packs instalados, pack activo, importar y
/// borrar.
class PacksPage extends ConsumerWidget {
  const PacksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = ref.watch(bundledPackSeedProvider);
    final busy = ref.watch(packsControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis packs'),
        actions: [
          IconButton(
            tooltip: 'Cambiar tema',
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: () =>
                ref.read(themeModeControllerProvider.notifier).toggle(),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: switch (seed) {
        AsyncData() => const _PackList(),
        AsyncError(:final error) => _SeedError(
          error: error,
          onRetry: () => ref.invalidate(bundledPackSeedProvider),
        ),
        _ => const _SeedingIndicator(),
      },
      floatingActionButton: switch (seed) {
        AsyncData() when ref.watch(_hasPacksProvider) =>
          FloatingActionButton.extended(
            onPressed: busy ? null : () => _importFromFile(context, ref),
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Importar'),
          ),
        _ => null,
      },
    );
  }
}

/// `true` si hay al menos un pack (el estado vacío ya trae su propio botón).
final _hasPacksProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(installedPacksProvider).value?.isNotEmpty ?? false,
);

/// Flujo completo de importar: selector → caso de uso → diálogo o aviso.
Future<void> _importFromFile(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(packsControllerProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  void notify(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final result = await controller.importFromFile();
  if (!context.mounted) return;

  switch (result) {
    case ImportCancelled():
      return;
    case ImportRejected(:final errors):
      await showInvalidPackDialog(context, errors);
    case ImportFinished(outcome: PackInstalled(:final pack)):
      notify('Pack «${pack.info.name}» instalado');
    case ImportFinished(outcome: PackUpdated(:final pack)):
      notify(
        'Pack «${pack.info.name}» actualizado a la versión '
        '${pack.info.version}',
      );
    case ImportFinished(outcome: final ImportNeedsConfirmation outcome):
      if (await confirmReplacePack(context, outcome)) {
        await controller.replace(outcome.pack);
        notify('Pack «${outcome.pack.info.name}» reemplazado');
      }
  }
}

class _SeedingIndicator extends StatelessWidget {
  const _SeedingIndicator();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Preparando el pack incluido…'),
      ],
    ),
  );
}

class _SeedError extends StatelessWidget {
  const _SeedError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('No se pudo preparar el pack incluido.'),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _PackList extends ConsumerWidget {
  const _PackList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(installedPacksProvider);
    final activeId = ref.watch(activePackIdProvider).value;

    return switch (packs) {
      AsyncData(value: []) => const _EmptyState(),
      AsyncData(:final value) => ListView(
        // Deja sitio al botón flotante para no tapar el último pack.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          for (final pack in value)
            _PackTile(pack: pack, isActive: pack.id == activeId),
        ],
      ),
      AsyncError(:final error) => Center(child: Text('Error: $error')),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(packsControllerProvider).isLoading;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes ningún pack',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Importa un fichero .pack.json para empezar a estudiar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : () => _importFromFile(context, ref),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Importar pack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackTile extends ConsumerWidget {
  const _PackTile({required this.pack, required this.isActive});

  final InstalledPack pack;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(packsControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;

    final tile = ListTile(
      leading: Icon(
        isActive ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isActive ? colors.primary : colors.outline,
        semanticLabel: isActive ? 'Pack activo' : null,
      ),
      title: Text(pack.name),
      subtitle: Text(
        'v${pack.version} · ${pack.questionCount} preguntas'
        '${isActive ? ' · Activo' : ''}',
      ),
      onTap: isActive ? null : () => controller.activate(pack.id),
      trailing: IconButton(
        tooltip: 'Borrar pack',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (await confirmDeletePack(context, pack.name)) {
            await controller.delete(pack.id);
          }
        },
      ),
    );

    return Card(
      child: isActive
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                tile,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: FilledButton.icon(
                    onPressed: () => context.go('/practice'),
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Practicar'),
                  ),
                ),
              ],
            )
          : tile,
    );
  }
}
