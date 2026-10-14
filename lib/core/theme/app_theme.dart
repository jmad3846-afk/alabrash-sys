import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color panelSurface = Color(0xFFFFFFFF); // Pure White
  static const Color panelBorder = Color(0xFFE2E8F0); // Subtle border
  static const Color brandPrimaryText = Color(0xFF0F172A); // Dark Slate
  static const Color brandSecondaryText = Color(0xFF64748B); // Slate 500
  static const Color accentPrimary = Color(0xFF2563EB); // Royal Blue 600
  static const Color partnersEquityAccent = Color(0xFFD97706); // Amber 600
  static const Color scrapBoxAccent = Color(0xFF059669); // Emerald 600
  static const Color orderDepositBoxAccent = Color(0xFF0284C7); // Sky Blue 600
  static const Color dangerWaste = Color(0xFFDC2626); // Red 600
  static const Color successGreen = Color(0xFF16A34A); // Green 600
  static const Color cardShadow = Color(0x0F0F172A);

  static const Color chipBgBlue = Color(0xFFEFF6FF);
  static const Color chipBgAmber = Color(0xFFFEF3C7);
  static const Color chipBgGreen = Color(0xFFD1FAE5);
  static const Color chipBgSky = Color(0xFFE0F2FE);
  static const Color chipBgRed = Color(0xFFFEE2E2);
}

class AppTheme {
  static ThemeData get lightTheme {
    final baseFont = GoogleFonts.tajawalTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.primaryBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentPrimary,
        secondary: AppColors.partnersEquityAccent,
        surface: AppColors.panelSurface,
        background: AppColors.primaryBackground,
        error: AppColors.dangerWaste,
        onPrimary: Colors.white,
        onSurface: AppColors.brandPrimaryText,
      ),
      textTheme: baseFont.copyWith(
        displayLarge: baseFont.displayLarge?.copyWith(
          color: AppColors.brandPrimaryText,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: baseFont.titleLarge?.copyWith(
          color: AppColors.brandPrimaryText,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: baseFont.titleMedium?.copyWith(
          color: AppColors.brandPrimaryText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseFont.bodyLarge?.copyWith(
          color: AppColors.brandPrimaryText,
        ),
        bodyMedium: baseFont.bodyMedium?.copyWith(
          color: AppColors.brandSecondaryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panelSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.panelBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panelSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}
