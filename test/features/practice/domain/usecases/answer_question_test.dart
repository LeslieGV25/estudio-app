import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/core/domain/session_mode.dart';
import 'package:estudio_app/features/practice/domain/practice_session_config.dart';
import 'package:estudio_app/features/practice/domain/usecases/answer_question.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/progress/domain/entities/study_session.dart';
import 'package:estudio_app/features/review/data/drift_review_repository.dart';
import 'package:estudio_app/features/review/domain/review_state.dart';
import 'package:estudio_app/features/review/domain/usecases/sync_review_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/review.dart';
import '../../../../helpers/study_questions.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const cal = FixedOffsetCalendar.madridSummer;
  late AppDatabase db;
  late DriftProgressRepository progress;
  late DriftReviewRepository review;
  late AnswerQuestion answer;
  late StudySession session;
  late DateTime now;

  final normal = studyQuestion('q1', correctKey: 'b');
  final voided = studyQuestion('q2', voided: true, provisionalKey: 'c');

  Future<Map<String, ReviewState>> reviewStates() =>
      review.watchStates('pack').first;

  setUp(() async {
    db = newTestDatabase();
    now = cal.at(2026, 10, 5, 10);
    progress = DriftProgressRepository(db, clock: () => now);
    review = DriftReviewRepository(db, clock: () => now);
    answer = AnswerQuestion(progress, SyncReviewState(progress, review, cal));
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

  group('repaso', () {
    test('un fallo mete la pregunta en el repaso, pendiente hoy', () async {
      await answer(session: session, question: normal, chosen: 'a', timeMs: 1);

      expect(await reviewStates(), {
        'q1': ReviewState(
          box: 0,
          correctStreak: 0,
          nextDue: cal.at(2026, 10, 5),
        ),
      });
    });

    test('«Saltar» también la mete en el repaso', () async {
      await answer(session: session, question: normal, chosen: null, timeMs: 1);

      expect((await reviewStates())['q1']?.box, 0);
    });

    test('un acierto sin fallos previos no la mete', () async {
      await answer(session: session, question: normal, chosen: 'b', timeMs: 1);

      expect(await reviewStates(), isEmpty);
    });

    test('un acierto cuando toca la sube de caja', () async {
      await answer(session: session, question: normal, chosen: 'a', timeMs: 1);
      now = cal.at(2026, 10, 6, 9);
      final reviewSession = await progress.startSession(
        packId: 'pack',
        mode: SessionMode.review,
        config: const PracticeSessionConfig(questionIds: ['q1']).toJson(),
      );

      await answer(
        session: reviewSession,
        question: normal,
        chosen: 'b',
        timeMs: 1,
      );

      expect(
        (await reviewStates())['q1'],
        ReviewState(box: 1, correctStreak: 1, nextDue: cal.at(2026, 10, 7)),
      );
    });

    test('una respuesta rechazada no toca el repaso', () async {
      await expectLater(
        () =>
            answer(session: session, question: voided, chosen: 'b', timeMs: 1),
        throwsStateError,
      );

      expect(await reviewStates(), isEmpty);
    });
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
