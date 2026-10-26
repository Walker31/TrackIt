import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/expense_provider.dart';
import '../../models/expenses.dart';
import '../app_snackbar.dart';
import '../confirm_dialog.dart';
import '../empty_state.dart';
import '../animated/fade_slide_in.dart';
import '../ledger_row.dart';

class TransactionList extends StatelessWidget {
  final ExpenseProvider provider;

  /// Opens [expense] for editing.
  final void Function(Expense expense)? onEdit;

  const TransactionList({super.key, required this.provider, this.onEdit});

  Future<void> _confirmDelete(BuildContext context, int expenseId) async {
    final shouldDelete = await confirmDestructive(
      context,
      title: 'Delete transaction?',
      message: 'It will be removed from this month. You can undo right after.',
    );

    if (shouldDelete && context.mounted) {
      final match = provider.monthExpenses.where((x) => x.id == expenseId);
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
      '${formatRupees(expense.amount)} ${expense.isIncome ? 'income' : 'expense'} deleted.',
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
    final expenses = provider.monthExpenses;
    if (expenses.isEmpty) {
      final month = DateFormat('MMMM').format(provider.selectedMonth);
      return EmptyState(
        card: true,
        icon: Icons.receipt_long_outlined,
        title: 'No transactions in $month',
        message: 'Tap + to add an expense or income.',
      );
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
              icon: provider.categoryOf(e).iconData,
              iconColor: provider.categoryOf(e).colorValue,
              title: e.description ?? provider.categoryOf(e).name,
              // Named entries keep their category visible.
              subtitle: [
                if (e.description != null) provider.categoryOf(e).name,
                DateFormat('hh:mm a').format(e.timestamp),
                if (e.paymentMethod != null) e.paymentMethod!.label,
              ].join(' · '),
              trailingLabel: e.isIncome ? 'you received' : 'you spent',
              trailingAmount: formatRupees(e.amount),
              trailingColor: e.isIncome ? AppColors.income : AppColors.outflow,
              onTap: onEdit == null ? null : () => onEdit!(e),
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
