import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum SnackbarType { success, error, warning, info }

/// The single way to show user feedback: a compact toast pinned to the
/// top-right corner, icon-led and themed for light/dark. It sits in the
/// root overlay, so it shows above bottom sheets and dialogs too. Only one
/// toast is shown at a time; a new one replaces the last. Swipe it right
/// to dismiss it early.
class AppSnackbar {
  AppSnackbar._();

  static OverlayEntry? _current;

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.success,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.error,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void warning(BuildContext context, String message) =>
      _show(context, message, SnackbarType.warning);

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    context,
    message,
    SnackbarType.info,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (identical(_current, entry)) _current = null;
  }

  static void _show(
    BuildContext context,
    String message,
    SnackbarType type, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!context.mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final previous = _current;
    if (previous != null) _remove(previous);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _Toast(
        message: message,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: Duration(seconds: type == SnackbarType.error ? 4 : 3),
        onDismissed: () => _remove(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _Toast extends StatefulWidget {
  final String message;
  final SnackbarType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onDismissed;

  const _Toast({
    required this.message,
    required this.type,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 160),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeIn,
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    final (icon, accent) = switch (widget.type) {
      SnackbarType.success => (Icons.check_circle_rounded, AppColors.income),
      SnackbarType.error => (Icons.error_rounded, AppColors.expense),
      SnackbarType.warning => (Icons.warning_amber_rounded, AppColors.accent),
      SnackbarType.info => (Icons.info_rounded, AppColors.primary),
    };
    final background = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightTextPrimary;
    final hasAction = widget.actionLabel != null && widget.onAction != null;

    return Positioned(
      top: media.padding.top + 12,
      right: 12,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(320, media.size.width - 24),
        ),
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.12, 0),
              end: Offset.zero,
            ).animate(_curve),
            child: Dismissible(
              key: const ValueKey('toast'),
              direction: DismissDirection.startToEnd,
              onDismissed: (_) {
                _timer?.cancel();
                widget.onDismissed();
              },
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  padding: EdgeInsets.fromLTRB(10, 8, hasAction ? 4 : 12, 8),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.45)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: AppTextStyles.bodySm.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasAction) ...[
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            widget.onAction!();
                            _close();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text(widget.actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
