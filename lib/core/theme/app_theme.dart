import 'package:flutter/material.dart';
import 'app_fonts.dart';
import '../../features/bible/view_model/bible_state.dart';

class AppTheme {
  static const Color kPrimaryGold = Color(0xFFF2CA50); // Novo Dourado Premium
  static const Color kBackgroundDark = Color(0xFF111223); // Deep Navy Black
  static const Color kSurfaceDark = Color(0xFF1E1E30); // Surface Navy
  static const Color kSurfaceDarkLow = Color(0xFF1A1A2C); // Surface Navy Low
  
  static const BoxDecoration backgroundDecoration = BoxDecoration(
    color: kBackgroundDark,
  );

  static const ScrollbarThemeData _hiddenScrollbarTheme = ScrollbarThemeData(
    thumbVisibility: WidgetStatePropertyAll(false),
    trackVisibility: WidgetStatePropertyAll(false),
    thickness: WidgetStatePropertyAll(0.0),
    interactive: false,
  );

  // ── Tema Claro ─────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scrollbarTheme: _hiddenScrollbarTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
      primary: const Color(0xFF4F46E5),
    ).copyWith(
      surfaceContainer: Colors.white,
      surfaceContainerHighest: const Color(0xFFF0F0F0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F7F7),
    textTheme: GoogleFonts.manropeTextTheme(), // Usando Manrope como no HTML

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(0xFF4F46E5),
      unselectedItemColor: Colors.grey,
      elevation: 0,
    ),
  );

  // ── Tema Escuro (Premium Pro) ─────────────────────────
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scrollbarTheme: _hiddenScrollbarTheme,
    colorScheme: const ColorScheme.dark(
      primary: kPrimaryGold,
      surface: kBackgroundDark,
      onSurface: Color(0xFFE2E0F9),
      secondary: Color(0xFFC4C3EA),
      tertiary: Color(0xFFBFCDFF),
      surfaceContainer: kSurfaceDark,
      surfaceContainerLow: kSurfaceDarkLow,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    scaffoldBackgroundColor: kBackgroundDark,
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
      displayMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
      displaySmall: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
      headlineMedium: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
      titleLarge: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.transparent,
      selectedItemColor: kPrimaryGold,
      unselectedItemColor: Color(0x99E2E0F9),
      elevation: 0,
      showUnselectedLabels: true,
    ),
  );

  // ── Tema Sépia ─────────────────────────────────────────
  static final ThemeData sepiaTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scrollbarTheme: _hiddenScrollbarTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryGold,
      brightness: Brightness.light,
      surface: const Color(0xFFF4ECD8),
      onSurface: const Color(0xFF5B4636),
      primary: const Color(0xFF8B5E3C),
    ).copyWith(
      surfaceContainer: const Color(0xFFEBE0C7),
      surfaceContainerHighest: const Color(0xFFE1D3B6),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF4ECD8),
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4ECD8),
    textTheme: GoogleFonts.outfitTextTheme(),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(0xFF8B5E3C),
      unselectedItemColor: Color(0xFF8C7A6B),
      elevation: 0,
    ),
  );

  // ── Tema Papel ─────────────────────────────────────────
  static final ThemeData paperTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scrollbarTheme: _hiddenScrollbarTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFB45309),
      brightness: Brightness.light,
      surface: const Color(0xFFF9F9F9),
      onSurface: const Color(0xFF2C2C2C),
      primary: const Color(0xFFB45309),
    ).copyWith(
      surfaceContainer: Colors.white,
      surfaceContainerHighest: const Color(0xFFF0F0F0),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF9F9F9),
      elevation: 0,
    ),
    scaffoldBackgroundColor: const Color(0xFFF9F9F9),
    textTheme: GoogleFonts.outfitTextTheme(),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Color(0xFFB45309),
      unselectedItemColor: Color(0xFF525252),
      elevation: 0,
    ),
  );

  /// Constrói o ThemeData dinâmico aplicando a família de fontes escolhida pelo usuário
  static ThemeData getTheme({
    required AppThemeMode mode,
    required String fontFamily,
  }) {
    ThemeData base;
    switch (mode) {
      case AppThemeMode.light:
        base = lightTheme;
        break;
      case AppThemeMode.dark:
        base = darkTheme;
        break;
      case AppThemeMode.sepia:
        base = sepiaTheme;
        break;
      case AppThemeMode.paper:
        base = paperTheme;
        break;
    }

    final dynamicTextTheme = GoogleFonts.getTextTheme(fontFamily, base.textTheme);

    return base.copyWith(
      textTheme: dynamicTextTheme,
      primaryTextTheme: dynamicTextTheme,
    );
  }
}