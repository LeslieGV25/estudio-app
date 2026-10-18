import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../packs/data/pack_providers.dart';
import '../../packs/domain/entities/pack_document.dart';
import '../../practice/presentation/practice_providers.dart';
import '../../progress/data/progress_providers.dart';
import '../../review/presentation/review_providers.dart';
import '../domain/exam_plan.dart';
import '../domain/exam_setup.dart';
import '../domain/usecases/load_exam_result.dart';
import '../domain/usecases/start_exam.dart';
import '../domain/usecases/submit_exam_part.dart';

part 'exam_providers.g.dart';

@riverpod
StartExam startExam(Ref ref) =>
    StartExam(ref.watch(progressRepositoryProvider));

@riverpod
SubmitExamPart submitExamPart(Ref ref) => SubmitExamPart(
  ref.watch(packContentRepositoryProvider),
  ref.watch(progressRepositoryProvider),
  ref.watch(syncReviewStateProvider),
);

@riverpod
Future<ExamRules> examRules(Ref ref, String packId) =>
    ref.watch(packContentRepositoryProvider).examRules(packId);

@riverpod
Future<ExamResult?> examResult(Ref ref, String sessionId) => LoadExamResult(
  ref.watch(packContentRepositoryProvider),
  ref.watch(progressRepositoryProvider),
)(sessionId);

/// Lo que va eligiendo la usuaria en la pantalla de simulacro.
@riverpod
class ExamSetupController extends _$ExamSetupController {
  @override
  ExamSetup build() => const ExamSetup();

  void setKind(ExamKind kind) => state = state.copyWith(kind: kind);

  void setSource(String sourceId) => state = state.copyWith(sourceId: sourceId);

  /// `null` = simulacro completo.
  void setExercise(String? exerciseId) =>
      state = state.copyWith(exerciseId: exerciseId);

  void setOnlyOfficial(bool value) =>
      state = state.copyWith(onlyOfficial: value);

  void setIncludeObsolete(bool value) =>
      state = state.copyWith(includeObsolete: value);
}

/// Simulacro que saldría con lo elegido. Como en la práctica, «Empezar» usa
/// exactamente este plan (el aleatorio se baraja con cada cambio).
@riverpod
Future<ExamPlan> examPlan(Ref ref, String packId) async {
  final setup = ref.watch(examSetupControllerProvider);
  final questions = await ref.watch(packQuestionsProvider(packId).future);
  final outline = await ref.watch(packOutlineProvider(packId).future);
  final rules = await ref.watch(examRulesProvider(packId).future);
  return ExamPlan.build(
    questions: questions,
    outline: outline,
    rules: rules,
    setup: _withDefaultSource(setup, ExamPlan.realExamSources(outline, rules)),
    random: ref.read(practiceRandomProvider),
  );
}

/// En examen real, si aún no se ha elegido examen (o el elegido no está en
/// este pack), se usa el primero.
ExamSetup _withDefaultSource(ExamSetup setup, List<Source> sources) {
  if (setup.kind != ExamKind.realExam) return setup;
  if (sources.any((s) => s.id == setup.sourceId)) return setup;
  return setup.copyWith(sourceId: sources.firstOrNull?.id);
}
