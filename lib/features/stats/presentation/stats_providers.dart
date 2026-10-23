import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/domain/session_mode.dart';
import '../../../core/utils/clock_provider.dart';
import '../../exam/domain/usecases/load_exam_result.dart';
import '../../packs/data/pack_providers.dart';
import '../../progress/data/progress_providers.dart';
import '../../review/data/review_providers.dart';
import '../../review/presentation/review_providers.dart';
import '../domain/exam_history.dart';
import '../domain/pack_stats.dart';
import '../domain/stats_filter.dart';
import '../domain/usecases/load_exam_history.dart';
import '../domain/usecases/load_pack_stats.dart';

part 'stats_providers.g.dart';

@riverpod
LoadPackStats loadPackStats(Ref ref) => LoadPackStats(
  ref.watch(packContentRepositoryProvider),
  ref.watch(progressRepositoryProvider),
  ref.watch(reviewRepositoryProvider),
  ref.watch(reviewCalendarProvider),
);

@riverpod
LoadExamHistory loadExamHistory(Ref ref) {
  final content = ref.watch(packContentRepositoryProvider);
  final progress = ref.watch(progressRepositoryProvider);
  return LoadExamHistory(content, progress, LoadExamResult(content, progress));
}

/// Filtro que la usuaria elige en la pantalla de estadísticas.
@riverpod
class StatsFilterController extends _$StatsFilterController {
  @override
  StatsFilter build() => const StatsFilter();

  /// Activa o quita un modo; siempre queda al menos uno.
  void toggleMode(SessionMode mode) {
    final modes = {...state.modes};
    if (!modes.remove(mode)) modes.add(mode);
    if (modes.isNotEmpty) state = state.copyWith(modes: modes);
  }

  void setSources(SourceFilter sources) =>
      state = state.copyWith(sources: sources);

  void setIncludeObsolete(bool value) =>
      state = state.copyWith(includeObsolete: value);
}

/// Estadísticas del pack con el filtro actual. Se calculan al abrir la
/// pantalla y con cada cambio de filtro.
@riverpod
Future<PackStats> packStats(Ref ref, String packId) async {
  // La caché de repaso (para las dominadas) tiene que estar al día.
  await ref.watch(reviewRebuildProvider(packId).future);
  return ref
      .watch(loadPackStatsProvider)
      .call(
        packId,
        filter: ref.watch(statsFilterControllerProvider),
        now: ref.watch(clockProvider)(),
      );
}

@riverpod
Future<ExamHistory> examHistory(Ref ref, String packId) =>
    ref.watch(loadExamHistoryProvider).call(packId);
