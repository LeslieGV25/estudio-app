import 'dart:math';

import 'package:estudio_app/core/db/app_database.dart';
import 'package:estudio_app/features/packs/data/drift_pack_content_repository.dart';
import 'package:estudio_app/features/packs/data/drift_pack_repository.dart';
import 'package:estudio_app/features/practice/domain/practice_filter.dart';
import 'package:estudio_app/features/practice/domain/practice_plan.dart';
import 'package:estudio_app/features/practice/domain/usecases/answer_practice_question.dart';
import 'package:estudio_app/features/practice/domain/usecases/load_practice_summary.dart';
import 'package:estudio_app/features/practice/domain/usecases/start_practice_session.dart';
import 'package:estudio_app/features/progress/data/drift_progress_repository.dart';
import 'package:estudio_app/features/progress/domain/session_summary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/packs.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftPackContentRepository content;
  late DriftProgressRepository progress;
  late LoadPracticeSummary loadSummary;

  const packId = 'test-completo';

  setUp(() async {
    db = newTestDatabase();
    await DriftPackRepository(db).save(loadPack(completoPath));
    content = DriftPackContentRepository(db);
    progress = DriftProgressRepository(db);
    loadSummary = LoadPracticeSummary(content, progress);
  });
  tearDown(() => db.close());

  test('reconstruye el resumen desde la base de datos', () async {
    final plan = PracticePlan.build(
      await content.questions(packId),
      const PracticeFilter(),
      random: Random(1),
    );
    final started = await StartPracticeSession(content, progress)(
      packId,
      plan,
    ) as PracticeStarted;
    final questions = await content.questionsByIds(
      packId,
      started.config.questionIds,
    );
    final answer = AnswerPracticeQuestion(progress);
    // Responde todas con «b» menos la última, que queda sin responder.
    for (final q in questions.take(questions.length - 1)) {
      await answer(
        session: started.session,
        question: q,
        chosen: 'b',
        timeMs: 1000,
      );
    }

    final summary = await loadSummary(started.session.id);

    expect(
      summary!.items.map((i) => i.question.id),
      started.config.questionIds,
    );
    expect(summary.unanswered, 1);
    expect(summary.items.last.outcome, AnswerOutcome.unanswered);
    expect(summary.correct + summary.wrong, questions.length - 1);
  });

  test('devuelve null si la sesión no existe', () async {
    expect(await loadSummary('no-existe'), isNull);
  });
}
