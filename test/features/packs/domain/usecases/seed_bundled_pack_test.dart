import 'package:estudio_app/features/packs/domain/usecases/seed_bundled_pack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockPackRepository packs;
  late MockSettingsRepository settings;
  const id = 'test-completo';

  setUpAll(registerPackFallbacks);

  setUp(() {
    packs = MockPackRepository();
    settings = MockSettingsRepository();
    when(() => packs.save(any())).thenAnswer((_) async {});
    when(() => settings.getActivePackId()).thenAnswer((_) async => null);
    when(() => settings.setActivePackId(any())).thenAnswer((_) async {});
    when(() => settings.markBundledPackSeeded()).thenAnswer((_) async {});
  });

  SeedBundledPack seed({String version = '2.1.0'}) => SeedBundledPack(
    packs,
    settings,
    loadBundledPack: () async => completoBytes(version: version),
  );

  void seeded(bool value) =>
      when(() => settings.isBundledPackSeeded()).thenAnswer((_) async => value);

  void installed(String? version) => when(() => packs.findById(id)).thenAnswer(
    (_) async => version == null ? null : installedPack(id, version: version),
  );

  group('primer arranque', () {
    test('instala el pack, lo activa y guarda la marca', () async {
      seeded(false);
      installed(null);

      expect(await seed()(), SeedResult.installed);

      verify(() => packs.save(any())).called(1);
      verify(() => settings.setActivePackId(id)).called(1);
      verify(() => settings.markBundledPackSeeded()).called(1);
    });

    test('no cambia el pack activo si ya había uno', () async {
      seeded(false);
      installed(null);
      when(() => settings.getActivePackId()).thenAnswer((_) async => 'otro');

      await seed()();

      verifyNever(() => settings.setActivePackId(any()));
    });

    test('si ya estaba instalado con la misma versión, no lo pisa', () async {
      seeded(false);
      installed('2.1.0');

      expect(await seed()(), SeedResult.unchanged);

      verifyNever(() => packs.save(any()));
      verify(() => settings.markBundledPackSeeded()).called(1);
    });
  });

  group('arranques siguientes', () {
    test('si la usuaria lo borró, no vuelve a instalarlo', () async {
      seeded(true);
      installed(null);

      expect(await seed()(), SeedResult.unchanged);

      verifyNever(() => packs.save(any()));
    });

    test('si la app trae una versión mayor, lo actualiza', () async {
      seeded(true);
      installed('2.0.0');

      expect(await seed(version: '2.1.0')(), SeedResult.updated);

      verify(() => packs.save(any())).called(1);
    });

    test('con la misma versión no hace nada', () async {
      seeded(true);
      installed('2.1.0');

      expect(await seed()(), SeedResult.unchanged);

      verifyNever(() => packs.save(any()));
      verifyNever(() => settings.markBundledPackSeeded());
    });

    test('nunca instala una versión anterior a la instalada', () async {
      seeded(true);
      installed('3.0.0');

      expect(await seed(version: '2.1.0')(), SeedResult.unchanged);

      verifyNever(() => packs.save(any()));
    });
  });
}
