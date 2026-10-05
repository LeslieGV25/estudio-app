import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/clock_provider.dart';
import '../../packs/data/pack_providers.dart';
import '../../practice/presentation/practice_providers.dart';
import '../../progress/data/progress_providers.dart';
import '../data/review_providers.dart';
import '../domain/review_overview.dart';
import '../domain/usecases/start_review_session.dart';
import '../domain/usecases/sync_review_state.dart';

part 'review_providers.g.dart';

@Riverpod(keepAlive: true)
SyncReviewState syncReviewState(Ref ref) => SyncReviewState(
  ref.watch(progressRepositoryProvider),
  ref.watch(reviewRepositoryProvider),
  ref.watch(reviewCalendarProvider),
);

/// Rehace la caché de repaso del pack una vez por arranque (keepAlive): se
/// lanza en cuanto algo enseña el repaso de ese pack (el contador de la
/// pantalla de inicio, para el pack activo). Corrige una caché que se
/// quedara atrasada si la app se cerró entre guardar una respuesta y
/// sincronizar.
@Riverpod(keepAlive: true)
Future<void> reviewRebuild(Ref ref, String packId) =>
    ref.watch(syncReviewStateProvider).rebuild(packId);

/// Situación del repaso del pack; se actualiza sola con cada respuesta.
@riverpod
Stream<ReviewOverview> reviewOverview(Ref ref, String packId) async* {
  await ref.watch(reviewRebuildProvider(packId).future);
  final questions = await ref.watch(packQuestionsProvider(packId).future);
  final clock = ref.watch(clockProvider);
  yield* ref
      .watch(reviewRepositoryProvider)
      .watchStates(packId)
      .map((states) => ReviewOverview.from(states, questions, clock()));
}

@riverpod
StartReviewSession startReviewSession(Ref ref) => StartReviewSession(
  ref.watch(packContentRepositoryProvider),
  ref.watch(reviewRepositoryProvider),
  ref.watch(progressRepositoryProvider),
  ref.watch(clockProvider),
);
