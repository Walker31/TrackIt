import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_transitions.dart';

class AppTheme {
  // iOS-style chevron for every automatic back button.
  static final _pageTransitions = PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: AppPageTransitionsBuilder(),
    },
  );

  // Sheets keep a phone-like width instead of spanning a desktop window.
  static const _bottomSheetTheme = BottomSheetThemeData(
    constraints: BoxConstraints(maxWidth: 640),
  );

  static final _actionIconTheme = ActionIconThemeData(
    backButtonIconBuilder: (context) =>
        const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
  );

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // Accent for text and outlines; fills keep the brand indigo.
    final primary = dark ? AppColors.darkAccent : AppColors.brand;
    final fill = dark ? AppColors.darkAccentFill : AppColors.brand;
    final background = dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final surfaceVariant = dark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;
    final textPrimary = dark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = dark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final hairline = dark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      actionIconTheme: _actionIconTheme,
      pageTransitionsTheme: _pageTransitions,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: fill,
        brightness: brightness,
        primary: primary,
        onPrimary: dark ? const Color(0xFF06231C) : Colors.white,
        secondary: dark ? AppColors.darkIncome : AppColors.secondary,
        surface: surface,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        surfaceContainerHighest: surfaceVariant,
        outline: hairline,
        outlineVariant: hairline,
        error: AppColors.expense,
      ),
      textTheme: TextTheme(bodyMedium: TextStyle(color: textPrimary)),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: AppTextStyles.h3.copyWith(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.h3.copyWith(color: textPrimary),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fill,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          shape: controlShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: controlShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: hairline),
          shape: controlShape,
          padding: buttonPadding,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: AppTextStyles.bodyMd.copyWith(
          color: dark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextTertiary,
        ),
      ),
      dividerTheme: DividerThemeData(color: hairline, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(
            BorderSide(color: primary.withValues(alpha: 0.3)),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? primary : textSecondary,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
