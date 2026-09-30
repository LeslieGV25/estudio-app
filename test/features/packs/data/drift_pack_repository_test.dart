import 'package:drift/drift.dart' hide isNull;
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftPackRepository repo;
  late DateTime now;

  final completo = loadPack(completoPath);
  final minimo = loadPack(ejemploMinimoPath);
  const completoId = 'test-completo';

  setUp(() {
    db = newTestDatabase();
    now = DateTime.utc(2026, 9, 30, 10);
    repo = DriftPackRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  /// Simula progreso de la usuaria en el pack completo.
  Future<void> addUserProgress() async {
    final session = await db
        .into(db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            packId: completoId,
            mode: SessionMode.practice,
            config: const {},
            startedAt: now,
          ),
        );
    await db
        .into(db.answers)
        .insert(
          AnswersCompanion.insert(
            sessionId: session.id,
            packId: completoId,
            questionId: 'e1-01',
            chosen: const Value('b'),
            isCorrect: true,
            timeMs: 3000,
          ),
        );
    await db
        .into(db.reviewStates)
        .insert(
          ReviewStatesCompanion.insert(
            packId: completoId,
            questionId: 'e1-01',
            box: 2,
            nextDue: now,
          ),
        );
    await db
        .into(db.settings)
        .insert(SettingsCompanion.insert(key: 'active_pack_id', value: 'x'));
  }

  Future<Map<String, int>> userDataCounts() async => {
    'sessions': await db.select(db.sessions).get().then((r) => r.length),
    'answers': await db.select(db.answers).get().then((r) => r.length),
    'review_state': await db
        .select(db.reviewStates)
        .get()
        .then((r) => r.length),
    'settings': await db.select(db.settings).get().then((r) => r.length),
  };

  group('save (instalar)', () {
    test('guarda todo el contenido del pack', () async {
      await repo.save(completo);

      expect(await contentCounts(db, completoId), {
        'blocks': 2,
        'topics': 3,
        'sources': 2,
        'source_exercises': 2,
        'contexts': 1,
        'questions': 6,
        'notes': 1,
        'exam_exercises': 2,
      });
    });

    test('conserva todos los campos de preguntas y simulacro', () async {
      await repo.save(completo);

      final voided = await (db.select(
        db.questions,
      )..where((q) => q.id.equals('e1-02'))).getSingle();
      expect(voided.options, {'a': '16', 'b': '32', 'c': '64'});
      expect(voided.correctKey, isNull);
      expect(voided.voided, isTrue);
      expect(voided.provisionalKey, 'b');
      expect(voided.exerciseId, 'e1');
      expect(voided.position, 1);

      final obsolete = await (db.select(
        db.questions,
      )..where((q) => q.id.equals('e1-03'))).getSingle();
      expect(obsolete.tags, ['normativa', 'derogada']);

      final exercises = await (db.select(
        db.examExercises,
      )..orderBy([(e) => OrderingTerm.asc(e.position)])).get();
      expect(
        exercises.map((e) => e.scoring),
        completo.examRules!.exercises.map((e) => e.scoring),
      );
      expect(exercises.last.durationMin, isNull);

      final pack = await db.select(db.packs).getSingle();
      expect(pack.examNote, 'Reglas de prueba.');
      expect(pack.installedAt, now);
    });

    test('importa el pack de Zaragoza completo', () async {
      await repo.save(loadPack(zaragozaPath));

      final pack = await repo.findById('zgz-tecnico-aux-informatica');
      expect(pack!.questionCount, 371);
      expect(pack.version, '1.1.0');
    });
  });

  group('save (actualizar)', () {
    PackDocument newVersion() => completo.copyWith(
      info: completo.info.copyWith(version: '2.2.0'),
      questions: [
        for (final q in completo.questions)
          if (q.id != 'e1-03')
            q.id == 'e1-01' ? q.copyWith(statement: 'Texto corregido') : q,
      ],
    );

    test('reemplaza el contenido y mantiene la fecha de instalación', () async {
      final installedAt = now;
      await repo.save(completo);
      now = now.add(const Duration(days: 3));

      await repo.save(newVersion());

      final pack = await repo.findById(completoId);
      expect(pack!.version, '2.2.0');
      expect(pack.questionCount, 5);
      expect(pack.installedAt, installedAt);
      expect(pack.updatedAt, now);

      final ids = await db.select(db.questions).map((q) => q.id).get();
      expect(ids, isNot(contains('e1-03')));
      final updated = await (db.select(
        db.questions,
      )..where((q) => q.id.equals('e1-01'))).getSingle();
      expect(updated.statement, 'Texto corregido');
    });

    test(
      'si falla a mitad, deshace todo y queda la versión anterior',
      () async {
        await repo.save(completo);
        // Dos preguntas con el mismo id violan la clave primaria al insertar
        // (el validador lo impediría; aquí se fuerza para probar el rollback).
        final broken = newVersion().copyWith(
          questions: [completo.questions.first, completo.questions.first],
        );

        await expectLater(repo.save(broken), throwsA(anything));

        final pack = await repo.findById(completoId);
        expect(pack!.version, '2.1.0');
        expect(pack.questionCount, 6);
      },
    );

    test('no toca sesiones, respuestas, repaso ni ajustes', () async {
      await repo.save(completo);
      await addUserProgress();
      final before = await userDataCounts();

      await repo.save(newVersion());

      expect(await userDataCounts(), before);
      final answer = await db.select(db.answers).getSingle();
      expect(answer.questionId, 'e1-01');
    });
  });

  group('delete', () {
    test('borra el contenido del pack y deja los demás intactos', () async {
      await repo.save(completo);
      await repo.save(minimo);

      await repo.delete(completoId);

      expect(await repo.findById(completoId), isNull);
      expect((await contentCounts(db, completoId)).values, everyElement(0));
      expect((await repo.findById('ejemplo-minimo'))!.questionCount, 2);
    });

    test('conserva el progreso y se recupera al reimportar', () async {
      await repo.save(completo);
      await addUserProgress();
      final before = await userDataCounts();

      await repo.delete(completoId);
      expect(await userDataCounts(), before);

      await repo.save(completo);
      // La respuesta vuelve a enlazar con su pregunta por pack_id + question_id.
      final linked = await db.select(db.answers).join([
        innerJoin(
          db.questions,
          db.questions.packId.equalsExp(db.answers.packId) &
              db.questions.id.equalsExp(db.answers.questionId),
        ),
      ]).get();
      expect(linked, hasLength(1));
    });

    test('borrar un pack que no existe no falla', () async {
      await expectLater(repo.delete('no-existe'), completes);
    });
  });

  group('consultas', () {
    test('findById devuelve null si no existe', () async {
      expect(await repo.findById('no-existe'), isNull);
    });

    test(
      'watchInstalledPacks ordena por nombre y emite con cada cambio',
      () async {
        final names = repo.watchInstalledPacks().map(
          (packs) => [for (final p in packs) '${p.name} (${p.questionCount})'],
        );
        final expectation = expectLater(
          names,
          emitsInOrder([
            isEmpty,
            ['Pack de prueba completo (6)'],
            ['Pack de ejemplo (2)', 'Pack de prueba completo (6)'],
            ['Pack de ejemplo (2)'],
          ]),
        );

        // Se espera a cada emisión antes del siguiente cambio para que el
        // stream no agrupe dos cambios en una sola emisión.
        await pumpEventQueue();
        await repo.save(completo);
        await pumpEventQueue();
        await repo.save(minimo);
        await pumpEventQueue();
        await repo.delete(completoId);
        await expectation;
      },
    );
  });
}
