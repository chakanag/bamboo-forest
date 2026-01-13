import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color bambooDeep = Color(0xFF2E5A1C); // Deep moss green
  static const Color bambooMedium = Color(0xFF5C8D44); // Fresh leaf green
  static const Color bambooLight = Color(0xFFD4E6C9); // Pale green highlight
  static const Color earthDark = Color(0xFF4A3F35); // Dark wood
  static const Color earthLight = Color(0xFFF7F5F0); // Rice paper / Cream
  static const Color alertRed = Color(0xFFD9534F);
  static const Color textMain = Color(0xFF2C3329); // Nearly black green
  static const Color textSub = Color(0xFF6B7A65); // Muted green-gray

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: earthLight,
      colorScheme: ColorScheme.light(
        primary: bambooDeep,
        secondary: bambooMedium,
        surface: Colors.white,
        background: earthLight,
        error: alertRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textMain,
        onBackground: textMain,
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
        displayLarge: TextStyle(
          color: textMain,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textMain,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textMain,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textMain,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textSub,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: earthLight,
        foregroundColor: textMain,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: bambooLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: bambooDeep,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bambooDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: bambooDeep,
          side: const BorderSide(color: bambooDeep),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bambooLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bambooLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bambooMedium, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
