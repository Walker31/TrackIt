import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../glass_container.dart';
import '../../providers/expense_provider.dart';
import '../../models/expenses.dart';
import '../app_snackbar.dart';
import '../animated/fade_slide_in.dart';
import '../animated/tap_scale.dart';

class TransactionList extends StatelessWidget {
  final ExpenseProvider provider;

  const TransactionList({super.key, required this.provider});

  Future<void> _confirmDelete(BuildContext context, int expenseId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Expense', style: AppTextStyles.h3),
        content: const Text(
          'Do you want to delete this expense?',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.expense),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      final match = provider.expenses.where((x) => x.id == expenseId);
      if (match.isNotEmpty) {
        await _deleteWithUndo(context, match.first);
      }
    }
  }

  Future<void> _deleteWithUndo(BuildContext context, Expense expense) async {
    await provider.deleteExpense(expense.id!);
    if (!context.mounted) return;
    AppSnackbar.info(
      context,
      '₹${expense.amount.toStringAsFixed(0)} ${expense.isIncome ? 'income' : 'expense'} deleted.',
      aboveNav: true,
      actionLabel: 'Undo',
      onAction: () => provider.addExpense(
        Expense(
          amount: expense.amount,
          category: expense.category,
          timestamp: expense.timestamp,
          description: expense.description,
          type: expense.type,
          categoryId: expense.categoryId,
          subcategoryId: expense.subcategoryId,
          eventId: expense.eventId,
          paymentMethod: expense.paymentMethod,
          attachmentUrl: expense.attachmentUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = provider.expenses;
    if (expenses.isEmpty) {
      return const Center(child: Text("No transactions found"));
    }

    // The list item's own context is gone once it is dismissed, so snackbars
    // must be raised from this (still-mounted) list-level context.
    final rootContext = context;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final e = expenses[index];
        return FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: Key(e.id.toString()),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _deleteWithUndo(rootContext, e),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.expense,
                ),
              ),
              child: TapScale(
                onTap: () {},
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 16,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPress: () {
                      final id = e.id;
                      if (id != null) {
                        _confirmDelete(context, id);
                      }
                    },
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
                                DateFormat('hh:mm a').format(e.timestamp),
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${e.isIncome ? '+' : '-'}₹${e.amount.toStringAsFixed(0)}",
                          style: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.bold,
                            color: e.isIncome
                                ? AppColors.income
                                : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
