import 'package:flutter/material.dart';

/// App color palette. Brand/semantic colors (primary, category accents) are
/// the same in both themes and stay `const`. Surface/text colors switch
/// with the active brightness — call [AppColors.sync] once per frame from
/// the app root (done in `main.dart`) and every other read just works.
class AppColors {
  AppColors._();

  static bool _isDark = false;

  /// Call once near the root of the widget tree, before anything below it
  /// reads a brightness-dependent color.
  static void sync(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  static bool get isDark => _isDark;

  // Brand — identical in both themes
  static const Color primary = Color(0xFF4F46E5); // Indigo
  static const Color secondary = Color(0xFF059669); // Emerald
  static const Color accent = Color(0xFFD97706); // Amber
  static const Color expense = Color(0xFFE11D48); // Rose
  static const Color income = Color(0xFF059669); // Emerald
  // Splitwise-style "money out / you owe" orange for ledger rows.
  static const Color outflow = Color(0xFFE8590C);
  static const Color workout = Color(0xFF7C3AED); // Violet

  // Light surfaces/text (also used directly by AppTheme.lightTheme)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F2F6);
  static const Color lightTextPrimary = Color(0xFF14151A);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);

  // Dark surfaces/text (also used directly by AppTheme.darkTheme)
  static const Color darkBackground = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF171C2A);
  static const Color darkSurfaceVariant = Color(0xFF232A3D);
  static const Color darkTextPrimary = Color(0xFFF3F5F9);
  static const Color darkTextSecondary = Color(0xFF9AA4B8);
  static const Color darkTextTertiary = Color(0xFF6B7688);

  static Color get background => _isDark ? darkBackground : lightBackground;
  static Color get surface => _isDark ? darkSurface : lightSurface;
  static Color get surfaceVariant =>
      _isDark ? darkSurfaceVariant : lightSurfaceVariant;
  static Color get inputFill => surfaceVariant;
  static Color get textPrimary => _isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      _isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary =>
      _isDark ? darkTextTertiary : lightTextTertiary;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Money-green launch gradient (splash; mirrored in web/index.html).
  static const LinearGradient splashGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get surfaceGradient => LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
