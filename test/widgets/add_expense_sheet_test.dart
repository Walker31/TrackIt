import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/money_service.dart';
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
    for (var i = 0; i < 12; i++) {
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

  /// Opens the sheet for a new entry; returns a getter for what was saved
  /// and how often it repeats.
  Future<(Expense?, String?) Function()> openNew(WidgetTester tester) async {
    // A tall window, so the save button is on screen.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Expense? saved;
    String? repeat;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => AddExpenseSheet(
                  onAdd: (e) => saved = e,
                  onRepeat: (_, f) => repeat = f.name,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settleIo(tester);
    return () => (saved, repeat);
  }

  testWidgets('a pasted bank SMS fills the form', (tester) async {
    final result = await openNew(tester);
    await tester.tap(find.text('Paste bank SMS'));
    await settleIo(tester);
    expect(find.text('Paste a bank SMS'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).last,
      'Rs.450.00 debited from A/c XX1234 on 21-11-26 to VPA swiggy@icici '
      '(UPI Ref No 432112345678).',
    );
    await tester.pump();
    expect(find.textContaining('Spent ₹450 · Swiggy'), findsOneWidget);
    await tester.tap(find.text('Fill in'));
    await settleIo(tester);

    await tester.tap(find.textContaining('Save ₹450'));
    await tester.pump();
    final (saved, _) = result();
    expect(saved!.amount, 450);
    expect(saved.description, 'Swiggy');
    expect(saved.paymentMethod, PaymentMethod.upi);
    expect(saved.timestamp.day, 21);
    expect(
      saved.categoryId,
      defaultCategories.firstWhere((c) => c.name == 'Food & Dining').id,
    );
  });

  testWidgets('a new dollar expense saves rupees, dollars and the repeat', (
    tester,
  ) async {
    final result = await openNew(tester);
    await tester.tap(find.text('USD'));
    await settleIo(tester);
    final fields = find.byType(TextField);
    // Description, amount, rate.
    await tester.enterText(fields.at(1), '12.5');
    await tester.enterText(fields.at(2), '83.27');
    await tester.pump();
    expect(find.text('= ₹1,040.88'), findsOneWidget);
    await tester.tap(find.text('Monthly'));
    await tester.pump();
    await tester.tap(find.textContaining('Save ₹1,040.88'));
    await tester.pump();
    final (saved, repeat) = result();
    expect(saved!.amount, 1040.88);
    expect(saved.currency, 'USD');
    expect(saved.originalAmount, 12.5);
    expect(repeat, 'monthly');
  });

  testWidgets('a foreign currency needs a rate', (tester) async {
    final result = await openNew(tester);
    await tester.tap(find.text('EUR'));
    await settleIo(tester);
    await tester.enterText(find.byType(TextField).at(1), '20');
    await tester.pump();
    await tester.tap(find.textContaining('Save'));
    await tester.pump();
    expect(find.textContaining('Enter the rate'), findsOneWidget);
    expect(result().$1, isNull);
  });
  testWidgets('a new entry is tied to the chosen account', (tester) async {
    late Account hdfc;
    late Account cash;
    await tester.runAsync(() async {
      hdfc = Account.create('HDFC', AccountKind.bank, 0);
      cash = Account.create('Cash', AccountKind.cash, 0);
      await AccountService().save(hdfc);
      await AccountService().save(cash);
    });
    final result = await openNew(tester);
    expect(find.text('From account'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '250');
    await tester.tap(find.text('HDFC'));
    await tester.pump();
    await tester.tap(find.textContaining('Save ₹250'));
    await tester.pump();
    expect(result().$1!.accountId, hdfc.id);
  });

  testWidgets('without accounts there is no account row', (tester) async {
    await openNew(tester);
    expect(find.text('From account'), findsNothing);
  });
}

/// Lets the sheet's database reads (real I/O) finish.
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
