import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart' show SqliteException;
import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = newTestDatabase());
  tearDown(() => db.close());

  Future<void> insertPack(String id) => db
      .into(db.packs)
      .insert(
        PacksCompanion.insert(
          id: id,
          name: 'Pack $id',
          version: '1.0.0',
          type: PackType.course,
          language: 'es',
          formatVersion: 1,
          installedAt: DateTime.utc(2026, 9, 30),
          updatedAt: DateTime.utc(2026, 9, 30),
        ),
      );

  Future<String> insertSession() async {
    final session = await db
        .into(db.sessions)
        .insertReturning(
          SessionsCompanion.insert(
            packId: 'p',
            mode: SessionMode.practice,
            config: const {},
            startedAt: DateTime.utc(2026, 9, 30),
          ),
        );
    return session.id;
  }

  Future<AnswerRow> insertAnswer(String sessionId) => db
      .into(db.answers)
      .insertReturning(
        AnswersCompanion.insert(
          sessionId: sessionId,
          packId: 'p',
          questionId: 'q1',
          chosen: const Value('a'),
          isCorrect: true,
          timeMs: 1200,
        ),
      );

  test('las claves foráneas están activadas', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.read<int>('foreign_keys'), 1);
  });

  test('borrar un pack borra su contenido en cascada', () async {
    await insertPack('p');
    await db
        .into(db.blocks)
        .insert(BlocksCompanion.insert(packId: 'p', id: 1, name: 'Bloque'));

    await (db.delete(db.packs)..where((p) => p.id.equals('p'))).go();

    expect(await db.select(db.blocks).get(), isEmpty);
  });

  test('no se puede insertar contenido de un pack inexistente', () async {
    expect(
      db
          .into(db.blocks)
          .insert(BlocksCompanion.insert(packId: 'nope', id: 1, name: 'B')),
      throwsA(isA<SqliteException>()),
    );
  });

  group('datos de usuario', () {
    test('ids UUID v4, usuario "local" y fechas en UTC por defecto', () async {
      final answer = await insertAnswer(await insertSession());

      expect(
        answer.id,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-')),
      );
      expect(answer.userId, 'local');
      expect(answer.answeredAt.isUtc, isTrue);
    });

    test('answers no admite UPDATE', () async {
      final answer = await insertAnswer(await insertSession());
      expect(
        (db.update(db.answers)..where((a) => a.id.equals(answer.id))).write(
          const AnswersCompanion(isCorrect: Value(false)),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('answers no admite DELETE', () async {
      final answer = await insertAnswer(await insertSession());
      expect(
        (db.delete(db.answers)..where((a) => a.id.equals(answer.id))).go(),
        throwsA(isA<SqliteException>()),
      );
    });

    test('la caja de Leitner solo puede ir de 0 a 4', () async {
      Future<void> insertBox(int box) => db
          .into(db.reviewStates)
          .insert(
            ReviewStatesCompanion.insert(
              packId: 'p',
              questionId: 'q$box',
              box: box,
              nextDue: DateTime.utc(2026, 10, 1),
            ),
          );

      await insertBox(4);
      expect(insertBox(5), throwsA(isA<SqliteException>()));
    });

    test('la configuración de sesión se guarda como JSON', () async {
      final id = await db
          .into(db.sessions)
          .insertReturning(
            SessionsCompanion.insert(
              packId: 'p',
              mode: SessionMode.exam,
              config: const {
                'temas': [1, 2],
                'oficiales': true,
              },
              startedAt: DateTime.utc(2026, 9, 30),
            ),
          )
          .then((s) => s.id);

      final session = await (db.select(
        db.sessions,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(session.mode, SessionMode.exam);
      expect(session.config, {
        'temas': [1, 2],
        'oficiales': true,
      });
      expect(session.deletedAt, isNull);
    });
  });
}
