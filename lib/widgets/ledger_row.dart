import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

export '../utils/format.dart';

/// Splitwise-style transaction row: date column, square category tile,
/// title with a "who paid" line, and a small label over the amount.
///
/// [onLongPress] is the row's secondary action (delete, or a menu). Touch
/// reaches it by long-pressing; a mouse by right-clicking, or with the
/// button that appears while the pointer is over the row.
class LedgerRow extends StatefulWidget {
  final DateTime date;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  /// e.g. "you lent", "you borrowed", "you spent".
  final String trailingLabel;

  /// Formatted amount, or null for rows with no stake ("not involved").
  final String? trailingAmount;
  final Color trailingColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Icon and tooltip of the hover button for [onLongPress].
  final IconData actionIcon;
  final String actionTooltip;

  const LedgerRow({
    super.key,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.trailingAmount,
    required this.trailingColor,
    this.onTap,
    this.onLongPress,
    this.actionIcon = Icons.more_horiz_rounded,
    this.actionTooltip = 'More actions',
  });

  @override
  State<LedgerRow> createState() => _LedgerRowState();
}

class _LedgerRowState extends State<LedgerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final onLongPress = w.onLongPress;
    final date = w.date;
    final icon = w.icon;
    final iconColor = w.iconColor;
    final title = w.title;
    final subtitle = w.subtitle;
    final trailingLabel = w.trailingLabel;
    final trailingAmount = w.trailingAmount;
    final trailingColor = w.trailingColor;
    final showAction = _hovered && onLongPress != null;

    return InkWell(
      onTap: w.onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      onHover: (hovering) => setState(() => _hovered = hovering),
      // Rows with only a secondary action still read as clickable.
      mouseCursor: w.onTap != null || onLongPress != null
          ? SystemMouseCursors.click
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text(
                    DateFormat('MMM').format(date),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.bodyLg.copyWith(
                      fontSize: 20,
                      height: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: iconColor.withValues(alpha: 0.25)),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailingLabel,
                  style: AppTextStyles.bodySm.copyWith(
                    color: trailingColor,
                    fontSize: 12,
                  ),
                ),
                if (trailingAmount != null)
                  Text(
                    trailingAmount,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: trailingColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              child: showAction
                  ? Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        tooltip: w.actionTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: onLongPress,
                        icon: Icon(
                          w.actionIcon,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// "October 2026"-style header above each month's rows.
class LedgerMonthHeader extends StatelessWidget {
  final DateTime month;
  const LedgerMonthHeader({super.key, required this.month});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        DateFormat('MMMM yyyy').format(month),
        style: AppTextStyles.bodyMd.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Lays out [rows] under month headers with hairline dividers, newest
/// first, given each row's date.
List<Widget> ledgerSections<T>(
  List<T> items,
  DateTime Function(T) dateOf,
  Widget Function(T item, int index) build,
) {
  final out = <Widget>[];
  DateTime? currentMonth;
  for (var i = 0; i < items.length; i++) {
    final d = dateOf(items[i]);
    final month = DateTime(d.year, d.month);
    if (month != currentMonth) {
      currentMonth = month;
      out.add(LedgerMonthHeader(month: month));
    } else {
      out.add(
        Divider(
          height: 1,
          indent: 46,
          color: AppColors.textTertiary.withValues(alpha: 0.18),
        ),
      );
    }
    out.add(build(items[i], i));
  }
  return out;
}
