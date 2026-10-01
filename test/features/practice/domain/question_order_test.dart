import 'dart:math';

import 'package:estudio_app/features/packs/domain/entities/study_question.dart';
import 'package:estudio_app/features/practice/domain/question_order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  /// 6 sueltas (s0–s5) y dos supuestos de 3 (x1–x3, y1–y3), con las
  /// posiciones del supuesto intercaladas y desordenadas en la lista.
  final candidates = [
    for (var i = 0; i < 6; i++) studyQuestion('s$i', position: i),
    studyQuestion('x3', position: 12, contextId: 'x'),
    studyQuestion('x1', position: 10, contextId: 'x'),
    studyQuestion('y1', position: 20, contextId: 'y'),
    studyQuestion('x2', position: 11, contextId: 'x'),
    studyQuestion('y2', position: 21, contextId: 'y'),
    studyQuestion('y3', position: 22, contextId: 'y'),
  ];

  List<String> ids(List<StudyQuestion> qs) => [for (final q in qs) q.id];

  /// Comprueba que cada supuesto aparece entero, seguido y en orden.
  void expectGroupsIntact(List<String> order) {
    for (final group in [
      ['x1', 'x2', 'x3'],
      ['y1', 'y2', 'y3'],
    ]) {
      final start = order.indexOf(group.first);
      if (start == -1) {
        expect(order.toSet().intersection(group.toSet()), isEmpty);
        continue;
      }
      expect(order.sublist(start, start + group.length), group);
    }
  }

  test('sin límite devuelve todas, una vez cada una', () {
    final order = ids(practiceOrder(candidates, random: Random(1)));

    expect(order, unorderedEquals(ids(candidates)));
  });

  test('los supuestos quedan juntos y en su orden con cualquier semilla', () {
    for (var seed = 0; seed < 200; seed++) {
      expectGroupsIntact(ids(practiceOrder(candidates, random: Random(seed))));
    }
  });

  test('baraja: no todas las semillas dan el mismo orden', () {
    final orders = {
      for (var seed = 0; seed < 20; seed++)
        ids(practiceOrder(candidates, random: Random(seed))).join(','),
    };

    expect(orders.length, greaterThan(1));
  });

  test('la misma semilla da el mismo orden', () {
    expect(
      ids(practiceOrder(candidates, random: Random(7))),
      ids(practiceOrder(candidates, random: Random(7))),
    );
  });

  group('límite', () {
    test('nunca pasa del límite ni parte un supuesto', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final limit in [1, 2, 4, 5, 7, 11]) {
          final order = ids(
            practiceOrder(candidates, limit: limit, random: Random(seed)),
          );
          expect(order.length, lessThanOrEqualTo(limit));
          expectGroupsIntact(order);
        }
      }
    });

    test('con sueltas de sobra se llena hasta el límite', () {
      for (var seed = 0; seed < 50; seed++) {
        final order = practiceOrder(candidates, limit: 5, random: Random(seed));
        expect(order, hasLength(5));
      }
    });

    test('un supuesto que no cabe se salta y se sigue con otros', () {
      // Límite 4: un supuesto de 3 + una suelta, o cuatro sueltas.
      final onlyGroupsAndOne = [
        studyQuestion('s', position: 0),
        ...candidates.where((q) => q.question.contextId != null),
      ];
      for (var seed = 0; seed < 50; seed++) {
        final order = ids(
          practiceOrder(onlyGroupsAndOne, limit: 4, random: Random(seed)),
        );
        expect(order, hasLength(4));
        expect(order, contains('s'));
        expectGroupsIntact(order);
      }
    });

    test('puede quedar por debajo si solo quedan supuestos grandes', () {
      // Límite 5 con dos supuestos de 3: cabe uno, el otro no.
      final onlyGroups = candidates
          .where((q) => q.question.contextId != null)
          .toList();

      final order = practiceOrder(onlyGroups, limit: 5, random: Random(3));

      expect(order, hasLength(3));
    });

    test('si no cabe ningún grupo entero, se corta el primero', () {
      final onlyGroups = candidates
          .where((q) => q.question.contextId != null)
          .toList();

      final order = ids(practiceOrder(onlyGroups, limit: 2, random: Random(3)));

      expect(order, anyOf(equals(['x1', 'x2']), equals(['y1', 'y2'])));
    });

    test('límite 0 o sin candidatas devuelve una lista vacía', () {
      expect(practiceOrder(candidates, limit: 0, random: Random(1)), isEmpty);
      expect(practiceOrder(const [], limit: 5, random: Random(1)), isEmpty);
    });
  });
}
