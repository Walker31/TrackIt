import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'animated/tap_scale.dart';

/// The description + amount pair at the top of the add-expense sheets,
/// laid out like Splitwise: a square tile on the left (category icon /
/// currency) and an underlined field beside it.
class ExpenseEntryFields extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  /// Icon and colour of the description tile (the chosen category).
  final IconData icon;
  final Color iconColor;

  /// Underline colour of the focused amount field.
  final Color accent;

  /// Tapping the category tile, e.g. to jump to the category picker.
  final VoidCallback? onIconTap;
  final ValueChanged<String>? onAmountChanged;
  final bool autofocus;

  const ExpenseEntryFields({
    super.key,
    required this.descriptionController,
    required this.amountController,
    required this.icon,
    required this.iconColor,
    required this.accent,
    this.onIconTap,
    this.onAmountChanged,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget categoryTile = _FieldTile(
      color: iconColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon), color: iconColor),
      ),
    );
    if (onIconTap != null) {
      categoryTile = Tooltip(
        message: 'Change category',
        child: TapScale(onTap: onIconTap, child: categoryTile),
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            categoryTile,
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: descriptionController,
                autofocus: autofocus,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 80,
                style: AppTextStyles.bodyLg.copyWith(fontSize: 18),
                decoration: _underline(
                  hint: 'Enter a description',
                  accent: AppColors.primary,
                ).copyWith(counterText: ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _FieldTile(
              color: AppColors.textSecondary,
              child: Text(
                '₹',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: amountController,
                onChanged: onAmountChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                  ),
                ],
                cursorColor: accent,
                style: _amountStyle(AppColors.textPrimary),
                decoration: _underline(
                  hint: '0.00',
                  accent: accent,
                  hintStyle: _amountStyle(
                    AppColors.textTertiary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static TextStyle _amountStyle(Color color) => AppTextStyles.h1.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: color,
  );

  /// Underline-only decoration (no fill), as in Splitwise.
  static InputDecoration _underline({
    required String hint,
    required Color accent,
    TextStyle? hintStyle,
  }) {
    final idle = UnderlineInputBorder(
      borderSide: BorderSide(
        color: AppColors.textTertiary.withValues(alpha: 0.5),
      ),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle:
          hintStyle ??
          AppTextStyles.bodyLg.copyWith(
            fontSize: 18,
            color: AppColors.textTertiary,
          ),
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.only(bottom: 8, top: 4),
      border: idle,
      enabledBorder: idle,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: accent, width: 2),
      ),
    );
  }
}

/// The square tile left of each field.
class _FieldTile extends StatelessWidget {
  final Color color;
  final Widget child;
  const _FieldTile({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}
