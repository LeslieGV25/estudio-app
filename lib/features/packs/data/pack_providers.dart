import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database_provider.dart';
import '../domain/repositories/pack_content_repository.dart';
import '../domain/repositories/pack_repository.dart';
import 'drift_pack_content_repository.dart';
import 'drift_pack_repository.dart';
import 'pack_file_picker.dart';

part 'pack_providers.g.dart';

/// Ruta del pack incluido en la app, tal cual se declara en `pubspec.yaml`.
const bundledPackAsset = 'packs/zgz-tai.pack.json';

// Los providers exponen la INTERFAZ: presentación nunca ve Drift, y en los
// tests se puede sustituir cualquier implementación con `overrideWith`.

@Riverpod(keepAlive: true)
PackRepository packRepository(Ref ref) =>
    DriftPackRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
PackContentRepository packContentRepository(Ref ref) =>
    DriftPackContentRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
PackFilePicker packFilePicker(Ref ref) => const FilePickerPackFilePicker();

/// Lee los bytes del pack incluido desde los assets de la app.
@Riverpod(keepAlive: true)
Future<List<int>> Function() bundledPackLoader(Ref ref) =>
    () async => (await rootBundle.load(bundledPackAsset)).buffer.asUint8List();
