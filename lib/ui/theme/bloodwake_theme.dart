import 'package:flutter/material.dart';

/// Shared palette for menus and game chrome.
abstract final class BloodwakeTheme {
  static const voidColor = Color(0xFF0B1017);
  static const panel = Color(0xEE121B23);
  static const line = Color(0xFF52606A);
  static const parchment = Color(0xFFF1E7D5);
  static const muted = Color(0xFFABB7BA);
  static const ember = Color(0xFFC9453A);
  static const gold = Color(0xFFD8B579);

  static ThemeData material() => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: voidColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ember,
      brightness: Brightness.dark,
      surface: panel,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: parchment),
      bodySmall: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ember,
        foregroundColor: parchment,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
  );
}
