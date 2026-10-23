import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum SnackbarType { success, error, warning, info }

/// The single way to show user feedback. Floating, rounded, icon-led and
/// themed for light/dark. Pass [aboveNav] on screens hosted inside the main
/// tab layout so the toast clears the floating bottom bar.
class AppSnackbar {
  AppSnackbar._();

  static void success(
    BuildContext context,
    String message, {
    bool aboveNav = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.success,
    aboveNav: aboveNav,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void error(
    BuildContext context,
    String message, {
    bool aboveNav = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.error,
    aboveNav: aboveNav,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void warning(
    BuildContext context,
    String message, {
    bool aboveNav = false,
  }) => _show(context, message, SnackbarType.warning, aboveNav: aboveNav);

  static void info(
    BuildContext context,
    String message, {
    bool aboveNav = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.info,
    aboveNav: aboveNav,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void _show(
    BuildContext context,
    String message,
    SnackbarType type, {
    required bool aboveNav,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (icon, accent) = switch (type) {
      SnackbarType.success => (Icons.check_circle_rounded, AppColors.income),
      SnackbarType.error => (Icons.error_rounded, AppColors.expense),
      SnackbarType.warning => (Icons.warning_amber_rounded, AppColors.accent),
      SnackbarType.info => (Icons.info_rounded, AppColors.primary),
    };

    final background = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightTextPrimary;
    const foreground = Colors.white;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          clipBehavior: Clip.none,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(16, 0, 16, aboveNav ? 112 : 16),
          duration: Duration(seconds: type == SnackbarType.error ? 4 : 3),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.bodyMd.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }
}
