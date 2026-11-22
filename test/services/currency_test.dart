import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/models/finance/currency.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/expense_service.dart';
import 'package:trackit/services/export_service.dart';

void main() {
  test('conversion rounds to paise; formatting uses the symbol', () {
    expect(toHome(12.5, 83.27), 1040.88);
    expect(toHome(1000, 0.56), 560);
    expect(currencyFor('USD').format(12.5), r'$12.50');
    expect(currencyFor('JPY').format(1200), '¥1,200');
    expect(currencyFor(null).isHome, isTrue);
    expect(currencyFor('XYZ').format(3), 'XYZ 3');
  });

  test('a foreign transaction keeps its currency on the device', () async {
    final db = await DatabaseService.openInMemoryForTesting();
    final saved = await ExpenseService().addExpense(
      Expense(
        amount: 1040.88,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 11, 20, 13),
        currency: 'USD',
        originalAmount: 12.5,
        description: 'Lunch in Singapore',
      ),
    );
    final row = (await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [saved.id],
    )).single;
    final back = Expense.fromMap(row);
    expect(back.isForeign, isTrue);
    expect(back.currency, 'USD');
    expect(back.originalAmount, 12.5);
    expect(back.amount, 1040.88);
    // The server only ever sees rupees.
    expect(back.toApi().containsKey('currency'), isFalse);
    expect(back.toApi()['amount'], '1040.88');

    final csv = await ExportService().transactionsCsv();
    expect(csv.trim().split('\n').last, endsWith(',USD,12.50'));
  });

  test('rupee transactions are not foreign', () {
    final e = Expense(
      amount: 100,
      category: ExpenseCategory.food,
      timestamp: DateTime(2026, 11, 20),
      currency: 'INR',
      originalAmount: 100,
    );
    expect(e.isForeign, isFalse);
  });
}
