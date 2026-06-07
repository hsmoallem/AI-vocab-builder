/// ─── App Theme — Material 3 Light & Dark ────────────────────────────
///
/// Defines the visual identity of the app using Material 3's
/// ColorScheme.fromSeed() — this generates a full color palette
/// from a single seed color, ensuring accessibility-compliant
/// contrast ratios automatically.
///
/// ## Why Material 3
/// Material 3 is the current Flutter standard. It provides:
///   - Dynamic color on Android 12+
///   - Consistent typography scale
///   - Better dark mode support than Material 2
///
/// ## Design choices
/// - **Primary:** Blue (#4A90D9) — calm, academic, readable
/// - **Accent/Review:** Green (#50C878) — "success" association
/// - **Rounded cards (12px)** — softer than default 4px Material radius
/// - **Filled input fields** — better for text-heavy form UIs

import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF4A90D9);
  static const Color accentColor = Color(0xFF50C878);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color cardColor = Color(0xFFF5F7FA);
  static const Color reviewColor = Color(0xFF50C878);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
      ),
    );
  }
}
