import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../../models/expenses.dart';
import '../../providers/expense_provider.dart';

class TransactionList extends StatelessWidget {
  final ExpenseProvider provider;

  const TransactionList({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = provider.expenses;
    if (expenses.isEmpty) {
      return const Center(child: Text("No transactions found"));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final e = expenses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key(e.id.toString()),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => provider.deleteExpense(e.id!),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.right(20),
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: AppColors.expense),
            ),
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
                    child: Icon(e.category.icon, color: e.category.color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.description ?? e.category.displayName, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                        Text(DateFormat('hh:mm a').format(e.timestamp), style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text("-₹${e.amount.toStringAsFixed(0)}", 
                    style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.expense)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
