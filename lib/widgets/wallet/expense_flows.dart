import 'package:flutter/material.dart';
import '../../providers/expense_provider.dart';
import '../../utils/format.dart';
import '../app_sheet.dart';
import '../app_snackbar.dart';
import 'add_expense_sheet.dart';
import '../../utils/sms_parser.dart';

/// Opens the add-expense sheet and confirms the saved expense, warning when
/// it takes the month over budget. Shared by the Wallet button, the Home
/// header and the `N` shortcut, so they all behave the same.
Future<void> openAddExpense(
  BuildContext context,
  ExpenseProvider provider, {
  ParsedSms? prefill,
}) {
  // Set by the sheet just before onAdd when the entry repeats, so one
  // message confirms both.
  String? repeats;
  return showAppSheet<void>(
    context: context,
    builder: (_) => AddExpenseSheet(
      prefill: prefill,
      onRepeat: (expense, frequency) {
        repeats = frequency.label.toLowerCase();
        provider.addRecurring(expense, frequency);
      },
      onAdd: (expense) async {
        await provider.addExpense(expense);
        if (!context.mounted) return;
        final label =
            '${formatRupees(expense.amount)} added to '
            '${provider.categoryOf(expense).name}.'
            '${repeats == null ? '' : ' Repeats $repeats (see Wallet › Recurring).'}';
        if (provider.monthlySpent > provider.monthlyBudget) {
          AppSnackbar.warning(
            context,
            '$label You are over your monthly budget.',
          );
        } else {
          AppSnackbar.success(context, label);
        }
      },
    ),
  );
}
