import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database_provider.dart';
import '../../../core/utils/clock_provider.dart';
import '../domain/progress_repository.dart';
import 'drift_progress_repository.dart';

part 'progress_providers.g.dart';

/// Usa el mismo reloj que el resto de la app: si los tests fijan la hora,
/// las respuestas y las sesiones se guardan con esa hora y no con la real.
@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) => DriftProgressRepository(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(clockProvider),
);
