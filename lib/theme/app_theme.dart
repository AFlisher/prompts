import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color black = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF141414);
  static const Color darkSurface = Color(0xFF1C1C1C);
  static const Color white = Color(0xFFFFFFFF);
  // Primary Light Theme scaffold/background color - deliberately distinct
  // from `white`, which stays pure white for cards/dialogs/sheets so those
  // surfaces remain visibly lighter than the page behind them.
  static const Color lightBackground = Color(0xFFFFFAF3);
  static const Color lightGray = Color(0xFFF0F0F0);
  static const Color mediumGray = Color(0xFF8A8A8A);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentPink = Color(0xFFE735F6);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Border radii
  static const double radiusSmall = 12.0;
  static const double radiusMedium = 18.0;
  static const double radiusLarge = 22.0;
  static const double radiusXL = 30.0;

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> heavyShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Same weight/blur/offset as [cardShadow], but theme-aware: a plain black
  /// shadow reads fine sitting on the Light Theme's cream page, but is
  /// invisible against the Dark Theme's near-black page - swap to a soft
  /// white glow there instead (the same trick already used for style cards).
  /// For controls that flip to a light/cream surface in Dark Mode (Home's
  /// top capsule, search bar, filter button) so their shadow stays visible
  /// against the dark page regardless of which theme is active.
  static List<BoxShadow> themeAwareShadow(bool isDarkMode) => [
        BoxShadow(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3),
      titleLarge: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600, color: color),
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: color),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: mediumGray),
      labelSmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: color),
    );
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: black,
      secondary: accentPurple,
      surface: white,
      surfaceContainerHighest: lightGray,
    ),
    textTheme: _buildTextTheme(ThemeData.light().textTheme, black),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: black,
    colorScheme: const ColorScheme.dark(
      primary: white,
      secondary: accentPurple,
      surface: darkCard,
      surfaceContainerHighest: darkSurface,
    ),
    textTheme: _buildTextTheme(ThemeData.dark().textTheme, white),
  );
}
