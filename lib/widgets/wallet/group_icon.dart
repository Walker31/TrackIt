import 'package:flutter/material.dart';

/// Material icons for the emoji offered when creating an event. The emoji
/// is what's stored and synced; drawing an icon instead means it shows the
/// same everywhere, including the web build, which has no emoji font.
const groupIconFor = <String, IconData>{
  '💰': Icons.savings_rounded,
  '✈️': Icons.flight_rounded,
  '✈': Icons.flight_rounded,
  '🏠': Icons.home_rounded,
  '🎉': Icons.celebration_rounded,
  '🍽️': Icons.restaurant_rounded,
  '🍽': Icons.restaurant_rounded,
  '🎬': Icons.movie_rounded,
  '🏖️': Icons.beach_access_rounded,
  '🏖': Icons.beach_access_rounded,
  '🎓': Icons.school_rounded,
};

/// An event's icon: a matching Material icon, or the emoji itself for
/// anything else someone typed.
class GroupIcon extends StatelessWidget {
  final String emoji;
  final double size;
  final Color? color;

  const GroupIcon(this.emoji, {super.key, this.size = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final icon = groupIconFor[emoji.trim()];
    if (icon == null) {
      return Text(emoji, style: TextStyle(fontSize: size));
    }
    return Icon(
      icon,
      size: size,
      color: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}
