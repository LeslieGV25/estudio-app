import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../packs/data/pack_providers.dart';
import '../../packs/domain/entities/pack_outline.dart';
import '../../packs/domain/entities/study_question.dart';
import '../../progress/data/progress_providers.dart';
import '../../progress/domain/entities/study_session.dart';
import '../../progress/domain/session_summary.dart';
import '../domain/usecases/answer_practice_question.dart';
import '../domain/usecases/load_practice_summary.dart';
import '../domain/usecases/start_practice_session.dart';

part 'practice_providers.g.dart';

@riverpod
StartPracticeSession startPracticeSession(Ref ref) => StartPracticeSession(
  ref.watch(packContentRepositoryProvider),
  ref.watch(progressRepositoryProvider),
);

@riverpod
AnswerPracticeQuestion answerPracticeQuestion(Ref ref) =>
    AnswerPracticeQuestion(ref.watch(progressRepositoryProvider));

/// Generador aleatorio para barajar; los tests ponen uno con semilla.
@Riverpod(keepAlive: true)
Random practiceRandom(Ref ref) => Random();

@riverpod
Future<PackOutline> packOutline(Ref ref, String packId) =>
    ref.watch(packContentRepositoryProvider).outline(packId);

/// Todas las preguntas del pack: la configuración las filtra en memoria con
/// cada cambio, sin volver a la base de datos.
@riverpod
Future<List<StudyQuestion>> packQuestions(Ref ref, String packId) =>
    ref.watch(packContentRepositoryProvider).questions(packId);

@riverpod
Future<({StudySession session, SessionSummary summary})?> practiceSummary(
  Ref ref,
  String sessionId,
) => LoadPracticeSummary(
  ref.watch(packContentRepositoryProvider),
  ref.watch(progressRepositoryProvider),
)(sessionId);
