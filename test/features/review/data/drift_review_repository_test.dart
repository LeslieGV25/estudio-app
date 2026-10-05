import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftReviewRepository repo;
  final now = DateTime.utc(2026, 10, 5, 8);

  ReviewState state(int box) =>
      ReviewState(box: box, correctStreak: box, nextDue: now);

  setUp(() {
    db = newTestDatabase();
    repo = DriftReviewRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<Map<String, ReviewState>> current(String packId) =>
      repo.watchStates(packId).first;

  test('saveStates inserta y vuelve a leer el estado', () async {
    await repo.saveStates('pack', {'q1': state(0), 'q2': state(3)});

    expect(await current('pack'), {'q1': state(0), 'q2': state(3)});
    final row = await db.select(db.reviewStates).get();
    expect(row.first.updatedAt, now);
  });

  test('saveStates sobrescribe y no toca las demás preguntas', () async {
    await repo.saveStates('pack', {'q1': state(0), 'q2': state(1)});

    await repo.saveStates('pack', {'q1': state(2)});

    expect(await current('pack'), {'q1': state(2), 'q2': state(1)});
  });

  test('null quita la pregunta de la caché', () async {
    await repo.saveStates('pack', {'q1': state(0), 'q2': state(1)});

    await repo.saveStates('pack', {'q1': null});

    expect(await current('pack'), {'q2': state(1)});
  });

  test('cada pack tiene su caché', () async {
    await repo.saveStates('pack-a', {'q1': state(0)});
    await repo.saveStates('pack-b', {'q1': state(4)});

    await repo.saveStates('pack-a', {'q1': null});

    expect(await current('pack-a'), isEmpty);
    expect(await current('pack-b'), {'q1': state(4)});
  });

  test('replaceAll sustituye la caché del pack entera', () async {
    await repo.saveStates('pack-a', {'q1': state(0), 'q2': state(1)});
    await repo.saveStates('pack-b', {'q9': state(1)});

    await repo.replaceAll('pack-a', {'q3': state(2)});

    expect(await current('pack-a'), {'q3': state(2)});
    expect(await current('pack-b'), {'q9': state(1)});
  });

  test('states lee la caché del pack de una vez', () async {
    await repo.saveStates('pack', {'q1': state(1)});
    await repo.saveStates('otro', {'q2': state(2)});

    expect(await repo.states('pack'), {'q1': state(1)});
  });

  test('watchStates emite con cada cambio', () async {
    final sizes = repo.watchStates('pack').map((s) => s.length);
    expect(sizes, emitsInOrder([0, 1, 2]));

    await pumpEventQueue();
    await repo.saveStates('pack', {'q1': state(0)});
    await pumpEventQueue();
    await repo.saveStates('pack', {'q2': state(0)});
  });
}
