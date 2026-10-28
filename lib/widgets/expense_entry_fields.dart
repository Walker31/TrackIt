import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'animated/tap_scale.dart';

/// The amount + note pair at the top of the add-expense sheets: a large
/// centred amount (the one thing every entry needs, focused on open) and
/// a note field led by the chosen category's icon.
class ExpenseEntryFields extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  /// Icon and colour of the chosen category, shown at the start of the
  /// note field.
  final IconData icon;
  final Color iconColor;

  /// Colour of the amount and its cursor (income teal / expense orange).
  final Color accent;

  /// Tapping the category icon, e.g. to jump to the category picker.
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
    Widget categoryIcon = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon), size: 18, color: iconColor),
      ),
    );
    if (onIconTap != null) {
      categoryIcon = Tooltip(
        message: 'Change category',
        child: TapScale(onTap: onIconTap, child: categoryIcon),
      );
    }

    return Column(
      children: [
        _AmountField(
          controller: amountController,
          accent: accent,
          autofocus: autofocus,
          onChanged: onAmountChanged,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: descriptionController,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLength: 80,
          style: AppTextStyles.bodyLg,
          decoration: InputDecoration(
            hintText: 'Add a note (optional)',
            counterText: '',
            prefixIcon: categoryIcon,
            prefixIconConstraints: const BoxConstraints(minHeight: 48),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Big centred amount with a ₹ sign that sits right next to the digits.
class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final Color accent;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  const _AmountField({
    required this.controller,
    required this.accent,
    required this.autofocus,
    this.onChanged,
  });

  static TextStyle _style(Color color) => AppTextStyles.h1.copyWith(
    fontSize: 44,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final empty = value.text.isEmpty;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '₹',
              style: _style(
                empty ? AppColors.textTertiary : accent,
              ).copyWith(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            // Grows with the digits so the ₹ stays attached, capped so long
            // amounts scroll inside the field instead of overflowing.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 60, maxWidth: 260),
              child: IntrinsicWidth(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  autofocus: autofocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,9}(\.\d{0,2})?'),
                    ),
                  ],
                  cursorColor: accent,
                  style: _style(AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: _style(AppColors.textTertiary),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
