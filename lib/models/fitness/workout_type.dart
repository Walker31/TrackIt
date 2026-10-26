import 'package:flutter/material.dart';

enum WorkoutType {
  push(
    'Push',
    'Upper body pushing movements',
    Color(0xFF6366F1),
    Icons.north_east_rounded,
  ),
  pull(
    'Pull',
    'Upper body pulling movements',
    Color(0xFF8B5CF6),
    Icons.south_west_rounded,
  ),
  legs(
    'Legs',
    'Lower body movements',
    Color(0xFF10B981),
    Icons.directions_run_rounded,
  );

  final String displayName;
  final String description;
  final Color color;
  final IconData icon;

  const WorkoutType(this.displayName, this.description, this.color, this.icon);

  static WorkoutType fromString(String name) {
    return WorkoutType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => WorkoutType.push,
    );
  }
}
