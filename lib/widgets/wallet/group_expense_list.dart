import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../models/expenses.dart';
import '../glass_container.dart';
import '../animated/fade_slide_in.dart';

class GroupExpenseList extends StatelessWidget {
  final List<GroupExpense> expenses;
  final List<GroupMember> members;

  const GroupExpenseList({
    super.key,
    required this.expenses,
    required this.members,
  });

  String _usernameFor(int memberId) {
    final match = members.where((m) => m.id == memberId);
    return match.isEmpty ? 'Unknown' : match.first.username;
  }

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const Center(child: Text("No expenses yet"));
    }

    return Column(
      children: expenses.asMap().entries.map((entry) {
        final index = entry.key;
        final e = entry.value;
        return FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: e.category.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      e.category.icon,
                      color: e.category.color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.description ?? e.category.displayName,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Paid by ${_usernameFor(e.payerMemberId)} · ${DateFormat('MMM d, hh:mm a').format(e.timestamp)}",
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₹${e.amount.toStringAsFixed(0)}",
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
