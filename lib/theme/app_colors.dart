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

  /// Brand indigo for filled surfaces (buttons, FABs) in the light theme.
  static const Color brand = Color(0xFF4F46E5);

  /// Dark theme follows Splitwise: neutral charcoal surfaces with a teal
  /// accent, mint for money coming in and orange for money going out.
  static const Color darkAccent = Color(0xFF1CC29F);
  static const Color darkAccentFill = Color(0xFF12A383);
  static const Color darkIncome = Color(0xFF5BC5A7);
  static const Color darkOutflow = Color(0xFFFF652F);

  /// Accent for text, icons and outlines drawn on the page background.
  static Color get primary => _isDark ? darkAccent : brand;

  /// Fill for buttons and FABs that carry white content.
  static Color get fill => _isDark ? darkAccentFill : brand;

  static Color get secondary => _isDark ? darkIncome : _emerald;
  static const Color accent = Color(0xFFD97706); // Amber
  static const Color expense = Color(0xFFE11D48); // Rose
  static Color get income => _isDark ? darkIncome : _emerald;
  // Splitwise-style "money out / you owe" orange for ledger rows.
  static Color get outflow => _isDark ? darkOutflow : const Color(0xFFE8590C);
  static const Color _emerald = Color(0xFF059669);
  static const Color workout = Color(0xFF7C3AED); // Violet

  // Light surfaces/text (also used directly by AppTheme.lightTheme)
  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F2F6);
  static const Color lightTextPrimary = Color(0xFF14151A);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);

  // Dark surfaces/text (also used directly by AppTheme.darkTheme)
  static const Color darkBackground = Color(0xFF1B1B1D);
  static const Color darkSurface = Color(0xFF262628);
  static const Color darkSurfaceVariant = Color(0xFF323235);
  static const Color darkTextPrimary = Color(0xFFF2F2F3);
  static const Color darkTextSecondary = Color(0xFFA9A9AE);
  static const Color darkTextTertiary = Color(0xFF7A7A80);

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

  /// Splitwise-style teal used for the logo tile in the dark theme.
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1CC29F), Color(0xFF0E8C73)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get brandGradient =>
      _isDark ? darkGradient : primaryGradient;

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
