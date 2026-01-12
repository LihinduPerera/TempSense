import 'package:flutter/material.dart';

class AppTheme {
  // Custom accent color (bright teal) – used for buttons, focused borders, and specific text
  static const Color primaryColor = Color(0xFF00BFA5); // Teal accent – vibrant and cooling

  // Base color for seed – generates the full harmonious palette
  static const Color seedColor = Color(0xFF00695C); // Deeper teal for better tonal variation

  // Other semantic colors (kept for potential future use)
  static const Color dangerColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFB300);
  static const Color infoColor = Color(0xFF29B6F6);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.transparent, // Keeps gradient backgrounds possible
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    // Optional: Add dark-mode specific input decoration if needed
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[850],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}