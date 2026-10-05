import '../domain/session_mode.dart';

/// Rutas de las pantallas de una sesión según su modo. Práctica y repaso
/// comparten pantallas; solo cambia la ruta base.
extension SessionRoutes on SessionMode {
  String get basePath => switch (this) {
    SessionMode.practice => '/practice',
    SessionMode.review => '/review',
    SessionMode.exam => '/exam',
  };

  String sessionPath(String sessionId) => '$basePath/session/$sessionId';

  String summaryPath(String sessionId) => '$basePath/summary/$sessionId';

  /// Nombre para títulos («Práctica», «Repaso»…).
  String get label => switch (this) {
    SessionMode.practice => 'Práctica',
    SessionMode.review => 'Repaso',
    SessionMode.exam => 'Simulacro',
  };
}
