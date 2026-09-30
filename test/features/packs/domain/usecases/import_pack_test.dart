import 'package:estudio_app/features/packs/domain/pack_parser.dart';
import 'package:estudio_app/features/packs/domain/usecases/import_pack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockPackRepository packs;
  late MockSettingsRepository settings;
  late ImportPack importPack;
  const id = 'test-completo';

  setUpAll(registerPackFallbacks);

  setUp(() {
    packs = MockPackRepository();
    settings = MockSettingsRepository();
    importPack = ImportPack(packs, settings);
    when(() => packs.save(any())).thenAnswer((_) async {});
    when(() => settings.getActivePackId()).thenAnswer((_) async => 'otro');
    when(() => settings.setActivePackId(any())).thenAnswer((_) async {});
  });

  void installed(String? version) => when(() => packs.findById(id)).thenAnswer(
    (_) async => version == null ? null : installedPack(id, version: version),
  );

  test('pack nuevo: lo instala', () async {
    installed(null);

    final outcome = await importPack(completoBytes());

    expect(outcome, isA<PackInstalled>());
    verify(() => packs.save(outcome.pack)).called(1);
    verifyNever(() => settings.setActivePackId(any()));
  });

  test('pack nuevo sin pack activo: además lo activa', () async {
    installed(null);
    when(() => settings.getActivePackId()).thenAnswer((_) async => null);

    await importPack(completoBytes());

    verify(() => settings.setActivePackId(id)).called(1);
  });

  test('versión mayor: actualiza sin preguntar', () async {
    installed('2.0.9');

    final outcome = await importPack(completoBytes(version: '2.1.0'));

    expect(
      outcome,
      isA<PackUpdated>().having((o) => o.previousVersion, 'previa', '2.0.9'),
    );
    verify(() => packs.save(any())).called(1);
  });

  test('misma versión: pide confirmación y no guarda nada', () async {
    installed('2.1.0');

    final outcome = await importPack(completoBytes(version: '2.1.0'));

    expect(
      outcome,
      isA<ImportNeedsConfirmation>()
          .having((o) => o.installedVersion, 'instalada', '2.1.0')
          .having((o) => o.isDowngrade, 'isDowngrade', isFalse),
    );
    verifyNever(() => packs.save(any()));
  });

  test('versión menor: pide confirmación indicando que es anterior', () async {
    installed('2.10.0');

    final outcome = await importPack(completoBytes(version: '2.9.0'));

    expect(
      outcome,
      isA<ImportNeedsConfirmation>().having(
        (o) => o.isDowngrade,
        'isDowngrade',
        isTrue,
      ),
    );
    verifyNever(() => packs.save(any()));
  });

  test('replace guarda el pack confirmado', () async {
    installed('2.1.0');
    final outcome = await importPack(completoBytes());

    await importPack.replace(outcome.pack);

    verify(() => packs.save(outcome.pack)).called(1);
  });

  test('fichero inválido: lanza InvalidPackException y no guarda', () async {
    expect(() => importPack([0x7B]), throwsA(isA<InvalidPackException>()));
    verifyNever(() => packs.save(any()));
  });
}
