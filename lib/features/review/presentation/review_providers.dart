import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../progress/data/progress_providers.dart';
import '../data/review_providers.dart';
import '../domain/usecases/sync_review_state.dart';

part 'review_providers.g.dart';

@riverpod
SyncReviewState syncReviewState(Ref ref) => SyncReviewState(
  ref.watch(progressRepositoryProvider),
  ref.watch(reviewRepositoryProvider),
  ref.watch(reviewCalendarProvider),
);
