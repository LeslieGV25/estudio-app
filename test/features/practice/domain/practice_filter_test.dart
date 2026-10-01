import 'package:estudio_app/features/practice/domain/practice_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  const all = PracticeFilter();

  group('por defecto', () {
    test('entra una pregunta normal', () {
      expect(all.matches(studyQuestion('q')), isTrue);
    });

    test('entran las de reserva, como normales', () {
      // `isReserve` no se mira en práctica.
      final q = studyQuestion('r');
      expect(
        all.matches(q.copyWith(question: q.question.copyWith(isReserve: true))),
        isTrue,
      );
    });

    test('quedan fuera anuladas y obsoletas', () {
      expect(
        all.matches(studyQuestion('a', voided: true, provisionalKey: 'b')),
        isFalse,
      );
      expect(all.matches(studyQuestion('o', obsolete: true)), isFalse);
    });

    test('entran las de fuentes no oficiales', () {
      expect(all.matches(studyQuestion('q', isOfficial: false)), isTrue);
    });
  });

  group('anuladas', () {
    const withVoided = PracticeFilter(includeVoided: true);

    test('«ver anuladas» incluye las que tienen respuesta provisional', () {
      expect(
        withVoided.matches(
          studyQuestion('a', voided: true, provisionalKey: 'b'),
        ),
        isTrue,
      );
    });

    test('las anuladas sin provisional no entran nunca', () {
      expect(withVoided.matches(studyQuestion('a', voided: true)), isFalse);
    });
  });

  test('includeObsolete incluye las obsoletas', () {
    expect(
      const PracticeFilter(includeObsolete: true)
          .matches(studyQuestion('o', obsolete: true)),
      isTrue,
    );
  });

  test('onlyOfficial deja fuera las de fuentes no oficiales', () {
    const filter = PracticeFilter(onlyOfficial: true);

    expect(filter.matches(studyQuestion('q', isOfficial: false)), isFalse);
    expect(filter.matches(studyQuestion('q')), isTrue);
  });

  test('sourceIds limita a esas fuentes', () {
    const filter = PracticeFilter(sourceIds: {'examen'});

    expect(filter.matches(studyQuestion('q', sourceId: 'examen')), isTrue);
    expect(filter.matches(studyQuestion('q', sourceId: 'estudio')), isFalse);
  });

  group('temario', () {
    const filter = PracticeFilter(topicIds: {1}, blockIds: {2});

    test('entra si su tema está elegido', () {
      expect(filter.matches(studyQuestion('q', topicId: 1)), isTrue);
    });

    test('entra si su bloque está elegido aunque el tema no', () {
      expect(
        filter.matches(studyQuestion('q', topicId: 9, blockId: 2)),
        isTrue,
      );
    });

    test('no entra si ni tema ni bloque están elegidos', () {
      expect(
        filter.matches(studyQuestion('q', topicId: 9, blockId: 0)),
        isFalse,
      );
    });
  });

  test('temario y fuente se combinan (Y)', () {
    const filter = PracticeFilter(topicIds: {1}, sourceIds: {'examen'});

    expect(filter.matches(studyQuestion('q', sourceId: 'estudio')), isFalse);
  });

  test('se guarda y se recupera en JSON', () {
    const filter = PracticeFilter(
      topicIds: {1, 3},
      blockIds: {2},
      sourceIds: {'examen'},
      onlyOfficial: true,
      includeVoided: true,
      questionCount: 20,
    );

    expect(PracticeFilter.fromJson(filter.toJson()), filter);
  });
}
