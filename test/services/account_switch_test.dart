import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/app_mode_service.dart';
import 'package:trackit/services/database_service.dart';

/// Logging out keeps the data on the phone. Someone else signing in next
/// must not see it, nor have it uploaded into their account.
void main() {
  late Database db;
  final modes = AppModeService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<void> seed() async {
    await db.insert('expenses', {
      ...Expense(
        amount: 120,
        category: ExpenseCategory.food,
        timestamp: DateTime(2026, 10, 30),
      ).toMap(),
      'remote_id': 9,
      'is_synced': 1,
    });
    await db.insert('categories', {
      'id': 'custom-1',
      'user_id': 'local',
      'name': 'Pets',
      'type': 'expense',
      'is_default': 0,
    });
    await db.insert('groups', {'name': 'Flat', 'remote_id': 3, 'is_synced': 1});
    await db.insert('settings', {
      'key': 'theme_mode',
      'value': 'dark',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> count(String table, [String? where]) async =>
      (await db.query(table, where: where)).length;

  test('a different account clears the previous one\'s data', () async {
    await modes.adoptAccount('asha');
    await seed();
    final defaults = await count('categories', 'is_default = 1');

    await modes.adoptAccount('ravi');

    expect(await count('expenses'), 0);
    expect(await count('groups'), 0);
    expect(await count('categories', 'is_default = 0'), 0);
    expect(await count('categories', 'is_default = 1'), defaults);
    final theme = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['theme_mode'],
    );
    expect(theme.single['value'], 'dark');
    expect(await modes.account(), startsWith('ravi@'));
  });

  test('signing in again as the same account keeps the data', () async {
    await modes.adoptAccount('asha');
    await seed();

    await modes.adoptAccount('asha');

    expect(await count('expenses'), 1);
    expect(await count('groups'), 1);
  });

  test('data made without an account is kept for the first one', () async {
    await seed();

    await modes.adoptAccount('asha');

    expect(await count('expenses'), 1);
    expect(await modes.account(), startsWith('asha@'));
  });

  test('an existing sign-in is recorded without clearing anything', () async {
    await seed();
    await modes.rememberAccount('asha');
    await modes.rememberAccount('ravi'); // already recorded: ignored

    expect(await modes.account(), startsWith('asha@'));
    expect(await count('expenses'), 1);
  });
}
