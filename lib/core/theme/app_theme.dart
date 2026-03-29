import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF3a38f1);
  static const Color onPrimary = Color(0xFFf0edff);
  static const Color primaryContainer = Color(0xFF4948fd);
  static const Color onPrimaryContainer = Color(0xFFffffff);
  
  static const Color background = Color(0xFFf9f9f9);
  static const Color onBackground = Color(0xFF2f3334);
  
  static const Color surface = Color(0xFFf9f9f9);
  static const Color onSurface = Color(0xFF2f3334);
  static const Color surfaceVariant = Color(0xFFdfe3e4);
  static const Color onSurfaceVariant = Color(0xFF5b6061);
  
  static const Color surfaceContainerLowest = Color(0xFFffffff);
  static const Color surfaceContainerLow = Color(0xFFf2f4f4);
  static const Color surfaceContainer = Color(0xFFeceeef);
  static const Color surfaceContainerHigh = Color(0xFFe6e9e9);
  static const Color surfaceContainerHighest = Color(0xFFdfe3e4);

  static const Color secondary = Color(0xFF5d5d72);
  static const Color onSecondary = Color(0xFFfbf7ff);
  static const Color secondaryContainer = Color(0xFFe2e0f9);
  static const Color onSecondaryContainer = Color(0xFF505064);

  static const Color tertiary = Color(0xFF745479);
  static const Color onTertiary = Color(0xFFfff7fb);
  static const Color tertiaryContainer = Color(0xFFf5cdf9);
  static const Color onTertiaryContainer = Color(0xFF604266);

  static const Color error = Color(0xFFa8364b);
  static const Color onError = Color(0xFFfff7f7);
  static const Color errorContainer = Color(0xFFf97386);
  static const Color onErrorContainer = Color(0xFF6e0523);

  static const Color outline = Color(0xFF777b7c);
  static const Color outlineVariant = Color(0xFFafb3b3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w800),
        displaySmall: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.plusJakartaSans(color: onSurface),
        bodyMedium: GoogleFonts.plusJakartaSans(color: onSurface),
        bodySmall: GoogleFonts.plusJakartaSans(color: onSurfaceVariant),
        labelLarge: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.plusJakartaSans(color: onSurfaceVariant, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.plusJakartaSans(color: onSurfaceVariant, fontWeight: FontWeight.w500),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimaryContainer,
      ),
    );
  }
}
