import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'animated/tap_scale.dart';

/// The description + amount pair at the top of the add-expense sheets, laid
/// out like Splitwise: two underlined fields, each led by a square tile —
/// the chosen category's icon beside the description, the rupee sign
/// beside the amount.
class ExpenseEntryFields extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController amountController;

  /// Icon and colour of the chosen category, shown in the description tile.
  final IconData icon;
  final Color iconColor;

  /// Colour of the rupee tile and the amount cursor (income teal / expense
  /// orange).
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

  static InputDecoration _underline(String hint, TextStyle hintStyle) =>
      InputDecoration(
        hintText: hint,
        hintStyle: hintStyle,
        counterText: '',
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.only(bottom: 8, top: 4),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget categoryTile = _Tile(
      color: iconColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(icon, key: ValueKey(icon), size: 24, color: iconColor),
      ),
    );
    if (onIconTap != null) {
      categoryTile = Tooltip(
        message: 'Change category',
        child: TapScale(onTap: onIconTap, child: categoryTile),
      );
    }

    final descriptionStyle = AppTextStyles.bodyLg.copyWith(
      fontSize: 18,
      color: AppColors.textPrimary,
    );
    final amountStyle = AppTextStyles.h1.copyWith(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.5,
      color: AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              categoryTile,
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: descriptionController,
                  autofocus: autofocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  style: descriptionStyle,
                  decoration: _underline(
                    'Enter a description',
                    descriptionStyle.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amountController,
                builder: (context, value, _) {
                  final color = value.text.isEmpty
                      ? AppColors.textSecondary
                      : accent;
                  return _Tile(
                    color: color,
                    child: Text(
                      '₹',
                      style: AppTextStyles.h2.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 14),
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
                  style: amountStyle,
                  decoration: _underline(
                    '0.00',
                    amountStyle.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Square, lightly tinted tile with a hairline border, like the ones
/// Splitwise puts beside its description and amount fields.
class _Tile extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Tile({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: child,
    );
  }
}
