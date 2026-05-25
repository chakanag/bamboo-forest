import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Light Mode — 보라빛 팔레트 ────────────────────────────────────────────
  static const Color purpleDeep    = Color(0xFF5B21B6); // 짙은 보라 (CTA)
  static const Color purpleMedium  = Color(0xFF8B5CF6); // 중간 보라 (강조)
  static const Color purpleLight   = Color(0xFFEDE9FE); // 연보라 (테두리·칩 bg)
  static const Color surfaceLight  = Color(0xFFFAF7FF); // 연보라 크림 (배경)
  static const Color textMain      = Color(0xFF1E1333); // 짙은 보라빛 검정
  static const Color textSub       = Color(0xFF6D5E8A); // 연보라 회색
  static const Color alertRed      = Color(0xFFDC2626);

  // ── Dark Mode — "심우주 보라" ──────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF080412); // 우주 보라-검정
  static const Color darkCard      = Color(0xFF130A20); // 짙은 보라 카드
  static const Color darkBorder    = Color(0xFF2D1A4A); // 보라 테두리
  static const Color darkPrimary   = Color(0xFFC084FC); // 달빛 연보라
  static const Color darkSecondary = Color(0xFFA855F7); // 보라 강조
  static const Color darkTextMain  = Color(0xFFFAF5FF); // 흰 보라빛
  static const Color darkTextSub   = Color(0xFFA78BFA); // 연보라 서브

  // ── Health State Colors — 경보색 대신 자연스러운 소멸 톤 ─────────────────────
  static const Color healthFading   = Color(0xFFD97706); // 앰버 — 촛불 꺼지듯
  static const Color healthCritical = Color(0xFFBE185D); // 로즈 — 노을처럼 스러짐
  // 하위 호환 alias
  static const Color healthOrange  = healthFading;
  static const Color healthRed     = healthCritical;

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceLight,
      colorScheme: ColorScheme.light(
        primary: purpleDeep,
        secondary: purpleMedium,
        surface: Colors.white,
        // ignore: deprecated_member_use
        background: surfaceLight,
        error: alertRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textMain,
        // ignore: deprecated_member_use
        onBackground: textMain,
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
        displayLarge: const TextStyle(
          color: textMain, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: const TextStyle(
          color: textMain, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(
          color: textMain, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(color: textMain, fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(color: textSub, fontSize: 14),
        bodySmall: const TextStyle(color: textSub, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
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
          side: const BorderSide(color: purpleLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: purpleDeep,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: purpleDeep,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: purpleDeep,
          side: const BorderSide(color: purpleDeep),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(color: textSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: purpleLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: purpleLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: purpleMedium, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: purpleDeep,
        labelColor: purpleDeep,
        unselectedLabelColor: textSub,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: purpleLight,
        labelStyle: const TextStyle(color: purpleDeep, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Dark Theme — "심우주 보라" ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkCard,
        // ignore: deprecated_member_use
        background: darkBg,
        error: alertRed,
        onPrimary: darkBg,
        onSecondary: darkBg,
        onSurface: darkTextMain,
        // ignore: deprecated_member_use
        onBackground: darkTextMain,
      ),
      textTheme: GoogleFonts.notoSansKrTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        displayLarge: const TextStyle(
          color: darkTextMain, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        headlineMedium: const TextStyle(
          color: darkTextMain, fontWeight: FontWeight.bold),
        titleLarge: const TextStyle(
          color: darkTextMain, fontWeight: FontWeight.w600),
        bodyLarge: const TextStyle(
          color: darkTextMain, fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(color: darkTextSub, fontSize: 14),
        bodySmall: const TextStyle(color: darkTextSub, fontSize: 12),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkTextMain,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkPrimary,
        foregroundColor: darkBg,
        elevation: 4,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkPrimary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        hintStyle: const TextStyle(color: darkTextSub),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: darkPrimary,
        labelColor: darkPrimary,
        unselectedLabelColor: darkTextSub,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkBorder,
        labelStyle: const TextStyle(color: darkPrimary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkCard,
        titleTextStyle: TextStyle(
          color: darkTextMain, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: darkTextSub, fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: darkCard,
        contentTextStyle: TextStyle(color: darkTextMain),
      ),
    );
  }
}
