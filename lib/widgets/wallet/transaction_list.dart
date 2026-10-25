import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../providers/expense_provider.dart';
import '../../models/expenses.dart';
import '../app_snackbar.dart';
import '../animated/fade_slide_in.dart';
import '../ledger_row.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ledgerSections<Expense>(
        expenses,
        (e) => e.timestamp,
        (e, index) => FadeSlideIn(
          index: index,
          child: Dismissible(
            key: Key(e.id.toString()),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _deleteWithUndo(rootContext, e),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: AppColors.expense.withValues(alpha: 0.12),
              child: const Icon(Icons.delete_outline, color: AppColors.expense),
            ),
            child: LedgerRow(
              date: e.timestamp,
              icon: e.category.icon,
              iconColor: e.category.color,
              title: e.description ?? e.category.displayName,
              // Named entries keep their category visible.
              subtitle: [
                if (e.description != null) e.category.displayName,
                DateFormat('hh:mm a').format(e.timestamp),
                if (e.paymentMethod != null) e.paymentMethod!.label,
              ].join(' · '),
              trailingLabel: e.isIncome ? 'you received' : 'you spent',
              trailingAmount: formatRupees(e.amount),
              trailingColor: e.isIncome ? AppColors.income : AppColors.outflow,
              onLongPress: () {
                final id = e.id;
                if (id != null) _confirmDelete(context, id);
              },
            ),
          ),
        ),
      ),
    );
  }
}
