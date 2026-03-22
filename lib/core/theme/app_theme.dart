/// TrendAI Design System — Colors, Typography, and ThemeData
/// All UI colors and gradients extracted from the Figma design.
library;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Color Palette
// ─────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Background
  static const backgroundDark = Color(0xFF050508);
  static const backgroundLight = Color(0xFFF3F4F6);
  static const cardDark = Color(0x0DFFFFFF); // white/5
  static const cardLight = Color(0xCCFFFFFF); // white/80

  // Brand
  static const primary = Color(0xFF6C5CE7);
  static const accent = Color(0xFF00C6FF);

  // Gradient
  static const gradientPrimary = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientPrimaryHorizontal = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Status
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);

  // Text
  static const textDark = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF111827);
  static const textMuted = Color(0xFF9CA3AF);

  // Platform-specific
  static const tikTok = Color(0xFFEC4899);
  static const instagram = Color(0xFFF97316);
  static const youtube = Color(0xFFEF4444);
  static const facebook = Color(0xFF3B82F6);
  static const x = Color(0xFF0EA5E9);
}

// ─────────────────────────────────────────────
// Typography
// ─────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display(BuildContext context) => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle headline(BuildContext context) => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      );

  static TextStyle title(BuildContext context) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle caption(BuildContext context) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
      );

  static TextStyle button(BuildContext context) => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );
}

// ─────────────────────────────────────────────
// ThemeData
// ─────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.backgroundDark,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10), width: 1),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.backgroundLight,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textLight,
        displayColor: AppColors.textLight,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.80),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
    );
  }
}
