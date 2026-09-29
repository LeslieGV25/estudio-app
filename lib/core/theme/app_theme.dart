import 'package:flutter/material.dart';

/// Tema Material 3 de la app, en variante clara y oscura, a partir de una
/// única semilla de color. El `ThemeMode` (claro/oscuro/sistema) se
/// gestiona aparte, en [ThemeModeController].
abstract final class AppTheme {
  static const _seedColor = Colors.teal;

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );

  static ThemeData get dark => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
