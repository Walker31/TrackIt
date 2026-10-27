import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ask before a destructive action. Resolves true only if confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(action, style: const TextStyle(color: AppColors.expense)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
