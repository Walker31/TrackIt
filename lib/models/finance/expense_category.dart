import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Categorical hues, validated with the dataviz skill's palette validator
/// (CVD-safe adjacency, lightness band, chroma floor) for both light and
/// dark surfaces — see scripts/validate_palette.js in that skill.
enum ExpenseCategory {
  food('Food', Icons.restaurant, Color(0xFF2A78D6), Color(0xFF3987E5)),
  transport(
    'Transport',
    Icons.directions_bus,
    Color(0xFFEB6834),
    Color(0xFFD95926),
  ),
  shopping(
    'Shopping',
    Icons.shopping_bag,
    Color(0xFF1BAF7A),
    Color(0xFF199E70),
  ),
  health(
    'Health',
    Icons.medical_services,
    Color(0xFFEDA100),
    Color(0xFFC98500),
  ),
  entertainment(
    'Entertainment',
    Icons.movie,
    Color(0xFFE87BA4),
    Color(0xFFD55181),
  ),
  other('Other', Icons.more_horiz, Color(0xFF008300), Color(0xFF008300));

  final String displayName;
  final IconData icon;
  final Color _lightColor;
  final Color _darkColor;

  const ExpenseCategory(
    this.displayName,
    this.icon,
    this._lightColor,
    this._darkColor,
  );

  Color get color => AppColors.isDark ? _darkColor : _lightColor;

  static ExpenseCategory fromString(String name) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }
}
