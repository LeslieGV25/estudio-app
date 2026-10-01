import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/practice/domain/practice_session_config.dart';
import 'package:estudio_app/features/practice/domain/usecases/answer_practice_question.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/progress/domain/entities/study_session.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/study_questions.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository progress;
  late AnswerPracticeQuestion answer;
  late StudySession session;

  final normal = studyQuestion('q1', correctKey: 'b');
  final voided = studyQuestion('q2', voided: true, provisionalKey: 'c');

  setUp(() async {
    db = newTestDatabase();
    progress = DriftProgressRepository(db);
    answer = AnswerPracticeQuestion(progress);
    session = await progress.startSession(
      packId: 'pack',
      mode: SessionMode.practice,
      config: const PracticeSessionConfig(questionIds: ['q1', 'q2']).toJson(),
    );
  });
  tearDown(() => db.close());

  test('corrige y guarda la respuesta como evento', () async {
    final result = await answer(
      session: session,
      question: normal,
      chosen: 'b',
      timeMs: 5000,
    );

    expect(result.isCorrect, isTrue);
    expect(result.chosen, 'b');
    expect(result.timeMs, 5000);
    expect(await progress.sessionAnswers(session.id), [result]);
  });

  test('una respuesta equivocada se guarda como fallo', () async {
    final result = await answer(
      session: session,
      question: normal,
      chosen: 'a',
      timeMs: 1,
    );

    expect(result.isCorrect, isFalse);
  });

  test('«Saltar» guarda una respuesta en blanco', () async {
    final result = await answer(
      session: session,
      question: normal,
      chosen: null,
      timeMs: 1,
    );

    expect(result.isBlank, isTrue);
    expect(result.isCorrect, isFalse);
  });

  test('una anulada no se puede responder en práctica', () async {
    expect(
      () => answer(session: session, question: voided, chosen: 'c', timeMs: 1),
      throwsStateError,
    );
    expect(await progress.sessionAnswers(session.id), isEmpty);
  });

  test('no se puede responder dos veces la misma pregunta', () async {
    await answer(session: session, question: normal, chosen: 'a', timeMs: 1);

    expect(
      () => answer(session: session, question: normal, chosen: 'b', timeMs: 1),
      throwsStateError,
    );
    expect(await progress.sessionAnswers(session.id), hasLength(1));
  });

  test('no se puede responder una pregunta que no es de la sesión', () async {
    expect(
      () => answer(
        session: session,
        question: studyQuestion('otra'),
        chosen: 'a',
        timeMs: 1,
      ),
      throwsStateError,
    );
  });
}
