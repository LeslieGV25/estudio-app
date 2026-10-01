import 'package:estudio_app/features/practice/domain/grading.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/study_questions.dart';

void main() {
  final normal = studyQuestion('q', correctKey: 'b').question;

  test('acierta con la letra correcta', () {
    expect(isCorrectAnswer(normal, 'b'), isTrue);
    expect(isCorrectAnswer(normal, 'a'), isFalse);
  });

  test('en blanco nunca es acierto', () {
    expect(isCorrectAnswer(normal, null), isFalse);
  });

  test('una anulada nunca es acierto, ni con la provisional', () {
    final voided = studyQuestion(
      'v',
      voided: true,
      provisionalKey: 'c',
    ).question;

    expect(isCorrectAnswer(voided, 'c'), isFalse);
  });
}
