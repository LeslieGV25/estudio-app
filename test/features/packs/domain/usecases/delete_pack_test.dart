import 'package:estudio_app/features/packs/domain/usecases/delete_pack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockPackRepository packs;
  late MockSettingsRepository settings;
  late DeletePack deletePack;

  setUp(() {
    packs = MockPackRepository();
    settings = MockSettingsRepository();
    deletePack = DeletePack(packs, settings);
    when(() => packs.delete(any())).thenAnswer((_) async {});
    when(() => settings.setActivePackId(any())).thenAnswer((_) async {});
  });

  void remaining(List<String> ids) => when(
    () => packs.watchInstalledPacks(),
  ).thenAnswer((_) => Stream.value([for (final id in ids) installedPack(id)]));

  test('borrar un pack que no es el activo no cambia el activo', () async {
    when(() => settings.getActivePackId()).thenAnswer((_) async => 'a');

    expect(await deletePack('b'), 'a');

    verify(() => packs.delete('b')).called(1);
    verifyNever(() => settings.setActivePackId(any()));
  });

  test('borrar el activo activa el primero que queda', () async {
    when(() => settings.getActivePackId()).thenAnswer((_) async => 'a');
    remaining(['b', 'c']);

    expect(await deletePack('a'), 'b');

    verify(() => settings.setActivePackId('b')).called(1);
  });

  test('borrar el último pack deja la app sin pack activo', () async {
    when(() => settings.getActivePackId()).thenAnswer((_) async => 'a');
    remaining([]);

    expect(await deletePack('a'), isNull);

    verify(() => settings.setActivePackId(null)).called(1);
  });

  test('borra antes de elegir el siguiente activo', () async {
    when(() => settings.getActivePackId()).thenAnswer((_) async => 'a');
    remaining([]);

    await deletePack('a');

    verifyInOrder([
      () => packs.delete('a'),
      () => packs.watchInstalledPacks(),
      () => settings.setActivePackId(null),
    ]);
  });
}
