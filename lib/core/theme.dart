import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryColor = Color(0xFF6B46C1);
  static const Color _backgroundColor = Color(0xFFFAF9F6);
  static const Color _surfaceColor = Color(0xFFFFFFFF);
  static const Color _errorColor = Color(0xFFDC2626);
  static const Color _textColor = Color(0xFF1F2937);
  static const Color _secondaryTextColor = Color(0xFF6B7280);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
      surface: _surfaceColor,
      background: _backgroundColor,
      error: _errorColor,
    ),
    scaffoldBackgroundColor: _backgroundColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: _backgroundColor,
      foregroundColor: _textColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: _textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: _textColor,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: _textColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: _textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: _textColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: _textColor,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        color: _textColor,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: _secondaryTextColor,
        fontSize: 14,
      ),
      bodySmall: TextStyle(
        color: _secondaryTextColor,
        fontSize: 12,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryColor,
        minimumSize: const Size(double.infinity, 56),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: const BorderSide(color: _primaryColor, width: 2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: _surfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );

  static const List<Color> colorPalette = [
    Colors.black,
    Color(0xFFDC2626), // Red
    Color(0xFFEC4899), // Pink
    Color(0xFF2563EB), // Blue  
    Color(0xFF16A34A), // Green
    Color(0xFFEAB308), // Yellow
    Color(0xFFEA580C), // Orange
    Color(0xFF9333EA), // Purple
    Color(0xFF92400E), // Brown
  ];
}