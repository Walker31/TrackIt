import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Filled text field used on the auth screens, with a leading icon. Styling
/// comes from the app's InputDecorationTheme.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 20, color: AppColors.textTertiary),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: AppColors.textTertiary),
      ),
    );
  }
}
