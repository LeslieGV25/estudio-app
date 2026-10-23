import '../../../packs/domain/repositories/pack_content_repository.dart';
import '../../../progress/domain/progress_repository.dart';
import '../../../review/domain/review_calendar.dart';
import '../../../review/domain/review_repository.dart';
import '../pack_stats.dart';
import '../stats_calculator.dart';
import '../stats_filter.dart';

/// Lee del pack y del progreso lo que necesita [StatsCalculator].
class LoadPackStats {
  const LoadPackStats(
    this._content,
    this._progress,
    this._review,
    this._calendar,
  );

  final PackContentRepository _content;
  final ProgressRepository _progress;
  final ReviewRepository _review;
  final ReviewCalendar _calendar;

  Future<PackStats> call(
    String packId, {
    required StatsFilter filter,
    required DateTime now,
  }) async => StatsCalculator.compute(
    outline: await _content.outline(packId),
    questions: await _content.questions(packId),
    answers: await _progress.packAnswers(packId, modes: filter.modes),
    reviewStates: await _review.states(packId),
    filter: filter,
    now: now,
    calendar: _calendar,
  );
}
