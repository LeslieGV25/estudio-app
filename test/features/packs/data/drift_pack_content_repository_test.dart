import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/packs.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftPackContentRepository repo;

  const completoId = 'test-completo';

  setUp(() async {
    db = newTestDatabase();
    repo = DriftPackContentRepository(db);
    final packs = DriftPackRepository(db);
    await packs.save(loadPack(completoPath));
    await packs.save(loadPack(ejemploMinimoPath));
  });
  tearDown(() => db.close());

  group('outline', () {
    test('devuelve bloques, temas y fuentes con sus ejercicios', () async {
      final outline = await repo.outline(completoId);

      expect(outline.blocks.map((b) => b.name), [
        'Bloque común',
        'Bloque técnico',
      ]);
      expect(outline.topics.map((t) => (t.id, t.blockId)), [
        (1, 0),
        (2, 1),
        (3, 1),
      ]);
      expect(outline.sources.map((s) => (s.id, s.isOfficial)), [
        ('examen-2026', true),
        ('estudio', false),
      ]);
      expect(outline.sources.first.exercises.map((e) => e.id), ['e1', 'e2']);
    });

    test('un pack que no existe devuelve listas vacías', () async {
      final outline = await repo.outline('no-existe');

      expect(outline.blocks, isEmpty);
      expect(outline.topics, isEmpty);
      expect(outline.sources, isEmpty);
    });
  });

  group('questions', () {
    test('todas las preguntas del pack en el orden del fichero', () async {
      final questions = await repo.questions(completoId);

      expect(questions.map((q) => q.id), [
        'e1-01',
        'e1-02',
        'e1-r1',
        'e1-03',
        'e2-01',
        'est-01',
      ]);
      expect(questions.map((q) => q.position), [0, 1, 2, 3, 4, 5]);
    });

    test('solo devuelve preguntas del pack pedido', () async {
      final minimo = loadPack(ejemploMinimoPath);

      final questions = await repo.questions(minimo.info.id);

      expect(
        questions.map((q) => q.id),
        minimo.questions.map((q) => q.id).toList(),
      );
    });

    test('reconstruye la pregunta igual que en el fichero', () async {
      final original = loadPack(completoPath).questions;

      final questions = await repo.questions(completoId);

      expect(questions.map((q) => q.question), original);
    });

    test('añade fuente, tema, bloque y contexto', () async {
      final questions = await repo.questions(completoId);
      final supuesto = questions.singleWhere((q) => q.id == 'e2-01');
      final estudio = questions.singleWhere((q) => q.id == 'est-01');

      expect(supuesto.sourceName, 'Examen 2026');
      expect(supuesto.isOfficial, isTrue);
      expect(supuesto.topicTitle, 'Linux');
      expect(supuesto.blockId, 1);
      expect(supuesto.context?.title, 'Supuesto 1');
      expect(supuesto.context?.code, contains('gzip'));

      expect(estudio.isOfficial, isFalse);
      expect(estudio.context, isNull);
    });
  });

  group('questionsByIds', () {
    test('respeta el orden pedido, no el del fichero', () async {
      final questions = await repo.questionsByIds(completoId, [
        'est-01',
        'e1-01',
        'e2-01',
      ]);

      expect(questions.map((q) => q.id), ['est-01', 'e1-01', 'e2-01']);
    });

    test('omite los ids que ya no existen en el pack', () async {
      final questions = await repo.questionsByIds(completoId, [
        'borrada',
        'e1-01',
      ]);

      expect(questions.map((q) => q.id), ['e1-01']);
    });
  });
}
