import 'dart:convert';
import 'dart:io';

import 'package:estudio_app/features/packs/domain/entities/pack_document.dart';
import 'package:estudio_app/features/packs/domain/pack_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = PackParser();
  List<int> bytesOf(String path) => File(path).readAsBytesSync();

  group('parse de packs válidos', () {
    test('pack de Zaragoza', () {
      final pack = parser.parse(bytesOf('packs/zgz-tai.pack.json'));

      expect(pack.info.id, 'zgz-tecnico-aux-informatica');
      expect(pack.info.type, PackType.competitiveExam);
      expect(pack.syllabus.topics, hasLength(40));
      expect(pack.questions, hasLength(371));
      expect(pack.questions.where((q) => q.voided), hasLength(11));
      expect(pack.contexts, hasLength(14));

      final ej1 = pack.examRules!.exercises.first;
      expect(ej1.questionCount, 50);
      expect(ej1.reserveCount, 5);
      expect(ej1.durationMin, 55);
      expect(ej1.scoring!.mode, ScoringMode.proportional);
      expect(ej1.scoring!.maxScore, 10);
      expect(ej1.scoring!.wrongFactor, 0.25);
      expect(ej1.scoring!.decimals, 3);
    });

    test('traduce todos los campos del pack completo', () {
      final pack = parser.parse(
        bytesOf('test/fixtures/packs/valid/completo.pack.json'),
      );
      Question question(String id) =>
          pack.questions.singleWhere((q) => q.id == id);

      expect(pack.info.version, '2.1.0');
      expect(pack.info.updatedOn, '2026-09-30');

      final exam = pack.sources.first;
      expect(exam.isOfficial, isTrue);
      expect(exam.answersOrigin, AnswersOrigin.officialFinalKey);
      expect(exam.exercises.first.examExerciseId, 'ej1');
      expect(pack.sources.last.date, isNull);
      expect(pack.sources.last.exercises, isEmpty);

      final normal = question('e1-01');
      expect(normal.options, {'a': '1976', 'b': '1978', 'c': '1982'});
      expect(normal.correctKey, 'b');
      expect(normal.voided, isFalse);
      expect(normal.isReserve, isFalse);
      expect(normal.tags, isEmpty);

      final voided = question('e1-02');
      expect(voided.voided, isTrue);
      expect(voided.correctKey, isNull);
      expect(voided.provisionalKey, 'b');

      expect(question('e1-r1').isReserve, isTrue);
      expect(question('e1-03').obsolete, isTrue);
      expect(question('e1-03').tags, ['normativa', 'derogada']);
      expect(question('e2-01').contextId, 'supuesto-1');
      expect(pack.contexts.single.code, contains('gzip'));
      expect(pack.contexts.single.language, 'bash');

      final ej2 = pack.examRules!.exercises.last;
      expect(ej2.durationMin, isNull);
      expect(ej2.hasCaseStudies, isTrue);
      expect(ej2.reserveCount, 0);
      expect(ej2.scoring!.mode, ScoringMode.fixed);
      expect(ej2.scoring!.wrong, -0.33);

      expect(pack.notes.single.topicId, 2);
    });

    test('acepta un BOM de UTF-8 al principio', () {
      final bytes = [
        0xEF,
        0xBB,
        0xBF,
        ...bytesOf('packs/ejemplo-minimo.pack.json'),
      ];
      expect(parser.parse(bytes).info.id, 'ejemplo-minimo');
    });
  });

  group('errores', () {
    Matcher invalidWith(String text) => isA<InvalidPackException>().having(
      (e) => e.errors,
      'errors',
      [contains(text)],
    );

    test('bytes que no son UTF-8', () {
      expect(
        () => parser.parse([0xFF, 0xFE, 0x00]),
        throwsA(invalidWith('UTF-8')),
      );
    });

    test('texto que no es JSON', () {
      expect(
        () => parser.parse(utf8.encode('{"formato": ')),
        throwsA(invalidWith('no es JSON válido')),
      );
    });

    test('JSON que no pasa el validador', () {
      expect(
        () => parser.parse(
          bytesOf('test/fixtures/packs/invalid/pregunta-duplicada.pack.json'),
        ),
        throwsA(invalidWith('pregunta duplicado: e1-01')),
      );
    });
  });
}
