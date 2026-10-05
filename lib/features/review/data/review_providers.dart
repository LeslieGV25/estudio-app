import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database_provider.dart';
import '../../progress/data/progress_providers.dart';
import '../domain/review_calendar.dart';
import '../domain/review_repository.dart';
import '../domain/usecases/sync_review_state.dart';
import 'drift_review_repository.dart';

part 'review_providers.g.dart';

@Riverpod(keepAlive: true)
ReviewRepository reviewRepository(Ref ref) =>
    DriftReviewRepository(ref.watch(appDatabaseProvider));

/// Días según la zona horaria del dispositivo; los tests ponen uno fijo.
@Riverpod(keepAlive: true)
ReviewCalendar reviewCalendar(Ref ref) => const LocalReviewCalendar();

@riverpod
SyncReviewState syncReviewState(Ref ref) => SyncReviewState(
  ref.watch(progressRepositoryProvider),
  ref.watch(reviewRepositoryProvider),
  ref.watch(reviewCalendarProvider),
);
