import 'dart:convert';
import 'dart:io';

import 'package:estudio_app/features/packs/domain/entities/installed_pack.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/repositories/pack_repository.dart';
import 'package:estudio_app/features/settings/domain/settings_repository.dart';
import 'package:mocktail/mocktail.dart';

import 'packs.dart';

class MockPackRepository extends Mock implements PackRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

/// Llamar en `setUpAll` de los tests que usen `any()` con un [PackDocument].
void registerPackFallbacks() {
  registerFallbackValue(loadPack(ejemploMinimoPath));
}

/// Bytes de `completo.pack.json` con la versión cambiada a [version].
List<int> completoBytes({String version = '2.1.0'}) {
  final json =
      jsonDecode(File(completoPath).readAsStringSync()) as Map<String, dynamic>;
  (json['pack'] as Map<String, dynamic>)['version'] = version;
  return utf8.encode(jsonEncode(json));
}

InstalledPack installedPack(String id, {String version = '1.0.0'}) =>
    InstalledPack(
      id: id,
      name: 'Pack $id',
      version: version,
      type: PackType.course,
      language: 'es',
      questionCount: 1,
      installedAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
