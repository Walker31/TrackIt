import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Round initial avatar. Each name always gets the same colour, so people
/// are easy to tell apart across lists (as in Splitwise).
class MemberAvatar extends StatelessWidget {
  final String name;
  final double size;

  const MemberAvatar({super.key, required this.name, this.size = 40});

  static const _palette = [
    Color(0xFF1CC29F),
    Color(0xFFFF652F),
    Color(0xFF4A90E2),
    Color(0xFF9B6BD6),
    Color(0xFFF5A623),
    Color(0xFFE5484D),
    Color(0xFF3BB4C1),
    Color(0xFF7CB342),
  ];

  static Color colorFor(String name) {
    final sum = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colorFor(name), shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: AppTextStyles.bodyLg.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
