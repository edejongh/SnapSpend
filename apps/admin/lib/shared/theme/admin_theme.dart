import 'package:flutter/material.dart';

class AdminTheme {
  static const Color primary = Color(0xFF1A73E8);
  static const Color sidebar = Color(0xFF1A1A2E);
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF4A5568);

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      background: background,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textDark,
        elevation: 0,
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: textMedium,
        ),
        dataRowColor: MaterialStateProperty.resolveWith(
          (states) => states.contains(MaterialState.hovered)
              ? primary.withOpacity(0.04)
              : null,
        ),
      ),
    );
  }
}
