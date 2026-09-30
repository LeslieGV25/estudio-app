import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/db/app_database_provider.dart';
import '../domain/settings_repository.dart';
import 'drift_settings_repository.dart';

part 'settings_providers.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    DriftSettingsRepository(ref.watch(appDatabaseProvider));
