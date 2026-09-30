import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/settings/data/drift_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;

  setUp(() {
    db = newTestDatabase();
    repo = DriftSettingsRepository(db);
  });
  tearDown(() => db.close());

  group('pack activo', () {
    test('no hay ninguno al empezar', () async {
      expect(await repo.getActivePackId(), isNull);
    });

    test('se guarda, se cambia y se quita', () async {
      await repo.setActivePackId('a');
      expect(await repo.getActivePackId(), 'a');

      await repo.setActivePackId('b');
      expect(await repo.getActivePackId(), 'b');

      await repo.setActivePackId(null);
      expect(await repo.getActivePackId(), isNull);
    });

    test('watchActivePackId emite cada cambio', () async {
      final expectation = expectLater(
        repo.watchActivePackId(),
        emitsInOrder([null, 'a', null]),
      );
      await pumpEventQueue();
      await repo.setActivePackId('a');
      await pumpEventQueue();
      await repo.setActivePackId(null);
      await expectation;
    });
  });

  test('marca de pack incluido ya importado', () async {
    expect(await repo.isBundledPackSeeded(), isFalse);
    await repo.markBundledPackSeeded();
    expect(await repo.isBundledPackSeeded(), isTrue);
  });
}
