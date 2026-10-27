import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Official Hospital Brand Palette
  static const Color primaryColor   = Color(0xFF1F6B4A); // Deep Heritage Hospital Green
  static const Color secondaryColor = Color(0xFF26875B); // Refined Mid-Green
  static const Color backgroundColor= Color(0xFFF3EFE6); // Premium Warm Linen / Sand
  static const Color surfaceColor   = Colors.white;
  static const Color cardColor      = Colors.white;
  static const Color textPrimary    = Color(0xFF143B2A); // Deep Greenish Charcoal
  static const Color textSecondary  = Color(0xFF5A6E64); // Sophisticated Muted Slate
  static const Color borderColor    = Color(0xFFDED8CB); // Harmonious Warm Linen Border
  static const Color errorColor      = Color(0xFFDC2626); // Clean Formal Red

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
        titleLarge: const TextStyle(color: textPrimary, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.5),
        titleMedium: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        bodyLarge: const TextStyle(color: textPrimary, fontSize: 16, height: 1.5),
        bodyMedium: const TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryColor),
        titleTextStyle: TextStyle(
          color: primaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryColor.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
      ),
    );
  }
}
