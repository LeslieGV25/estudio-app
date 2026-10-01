import 'package:estudio_app/features/practice/domain/grading.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  final normal = studyQuestion('q', correctKey: 'b').question;
  final voided = studyQuestion('v', voided: true, provisionalKey: 'c').question;

  test('acierta con la letra correcta', () {
    expect(isCorrectAnswer(normal, 'b'), isTrue);
    expect(isCorrectAnswer(normal, 'a'), isFalse);
  });

  test('en blanco nunca es acierto', () {
    expect(isCorrectAnswer(normal, null), isFalse);
  });

  test('una anulada se corrige con la provisional', () {
    expect(practiceKey(voided), 'c');
    expect(isCorrectAnswer(voided, 'c'), isTrue);
  });

  test('una anulada sin provisional no tiene respuesta buena', () {
    final noKey = studyQuestion('v', voided: true).question;

    expect(practiceKey(noKey), isNull);
    expect(isCorrectAnswer(noKey, null), isFalse);
    expect(isCorrectAnswer(noKey, 'a'), isFalse);
  });
}
