import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/widgets/wallet/add_expense_sheet.dart';

void main() {
  setUp(() async => DatabaseService.openInMemoryForTesting());

  Future<Expense?> editAndSave(WidgetTester tester, Expense initial) async {
    Expense? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    AddExpenseSheet(initial: initial, onAdd: (e) => saved = e),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // The sheet reads categories from the database: let real I/O finish.
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    return saved;
  }

  testWidgets('editing keeps the receipt photo', (tester) async {
    final saved = await editAndSave(
      tester,
      Expense(
        id: 7,
        amount: 250,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 11, 20, 13),
        attachmentUrl: 'https://example.com/r.jpg',
      ),
    );
    expect(saved, isNotNull);
    expect(saved!.attachmentUrl, 'https://example.com/r.jpg');
  });

  testWidgets('a foreign amount opens in its currency and saves the same', (
    tester,
  ) async {
    final saved = await editAndSave(
      tester,
      Expense(
        id: 8,
        amount: 1040.88,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 11, 20, 13),
        currency: 'USD',
        originalAmount: 12.5,
      ),
    );
    expect(find.text(r'$'), findsOneWidget);
    expect(saved!.currency, 'USD');
    expect(saved.originalAmount, 12.5);
    expect(saved.amount, closeTo(1040.88, 0.01));
  });
}
