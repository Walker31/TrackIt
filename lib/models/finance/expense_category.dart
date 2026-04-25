import 'package:flutter/material.dart';

enum ExpenseCategory {
  food('Food', Icons.restaurant, Color(0xFFFF9F1C)),
  transport('Transport', Icons.directions_bus, Color(0xFF2EC4B6)),
  shopping('Shopping', Icons.shopping_bag, Color(0xFFE71D36)),
  health('Health', Icons.medical_services, Color(0xFF011627)),
  entertainment('Entertainment', Icons.movie, Color(0xFF9B5DE5)),
  other('Other', Icons.more_horiz, Color(0xFF7209B7));

  final String displayName;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.displayName, this.icon, this.color);

  static ExpenseCategory fromString(String name) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ExpenseCategory.other,
    );
  }
}
