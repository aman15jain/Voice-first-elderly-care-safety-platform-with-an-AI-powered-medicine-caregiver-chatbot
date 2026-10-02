import 'package:flutter/material.dart';

/// Elder-friendly Material 3 theme: high contrast, large type, large touch targets.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5FA5),
      brightness: Brightness.light,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      textTheme: base.textTheme.copyWith(
        bodyLarge: const TextStyle(fontSize: 22),
        bodyMedium: const TextStyle(fontSize: 20),
        titleMedium: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
      visualDensity: VisualDensity.comfortable,
    );
  }
}
