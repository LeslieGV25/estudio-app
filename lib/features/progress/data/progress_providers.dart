import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database_provider.dart';
import '../domain/progress_repository.dart';
import 'drift_progress_repository.dart';

part 'progress_providers.g.dart';

@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) =>
    DriftProgressRepository(ref.watch(appDatabaseProvider));
