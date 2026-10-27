import 'package:flutter/material.dart';

/// App color palette, modelled on Splitwise: neutral greys, one teal
/// accent, teal for money coming in and orange for money going out.
/// Surface/text colors switch with the active brightness — call
/// [AppColors.sync] once per frame from the app root (done in `main.dart`)
/// and every other read just works.
class AppColors {
  AppColors._();

  static bool _isDark = false;

  /// Call once near the root of the widget tree, before anything below it
  /// reads a brightness-dependent color.
  static void sync(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  static bool get isDark => _isDark;

  /// Splitwise teal. Fills buttons and FABs in both themes.
  static const Color brand = Color(0xFF1CC29F);

  /// Deeper teal so text and icons stay readable on white.
  static const Color lightAccent = Color(0xFF0F9D7E);
  static const Color darkAccent = brand;

  static const Color lightIncome = Color(0xFF12A383);
  static const Color darkIncome = Color(0xFF5BC5A7);
  static const Color lightOutflow = Color(0xFFF2541B);
  static const Color darkOutflow = Color(0xFFFF652F);

  /// Accent for text, icons and outlines drawn on the page background.
  static Color get primary => _isDark ? darkAccent : lightAccent;

  /// Fill for buttons and FABs that carry white content.
  static Color get fill => brand;

  static Color get secondary => income;
  static const Color accent = Color(0xFFD97706); // Amber, for warnings
  static const Color expense = Color(0xFFE5484D); // Red, errors and deletes
  static Color get income => _isDark ? darkIncome : lightIncome;

  /// "Money out / you owe" orange for amounts and balances.
  static Color get outflow => _isDark ? darkOutflow : lightOutflow;
  static const Color workout = Color(0xFF9B6BD6); // Purple

  // Light surfaces/text (also used directly by AppTheme.lightTheme)
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F2F2);
  static const Color lightTextPrimary = Color(0xFF222222);
  static const Color lightTextSecondary = Color(0xFF6B6B6B);
  static const Color lightTextTertiary = Color(0xFF9B9B9B);

  // Dark surfaces/text (also used directly by AppTheme.darkTheme)
  static const Color darkBackground = Color(0xFF1C1C1C);
  static const Color darkSurface = Color(0xFF272727);
  static const Color darkSurfaceVariant = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFF2F2F2);
  static const Color darkTextSecondary = Color(0xFFA8A8A8);
  static const Color darkTextTertiary = Color(0xFF7A7A7A);

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

  /// Splitwise teal for the logo tile, brand panel and splash.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1CC29F), Color(0xFF0E8C73)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get brandGradient => primaryGradient;

  /// Launch gradient (splash; mirrored in web/index.html).
  static const LinearGradient splashGradient = primaryGradient;

  static LinearGradient get surfaceGradient => LinearGradient(
    colors: [surface, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
