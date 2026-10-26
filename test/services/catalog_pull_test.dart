import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/catalog_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Pulling categories and subcategories. Pulled categories used to be
/// insert-only, so a rename on the server never reached the device.
void main() {
  late Database db;
  final sync = SyncService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<Map<String, Object?>> category(String id) async =>
      (await db.query('categories', where: 'id = ?', whereArgs: [id])).single;

  test('server edits to a synced category apply', () async {
    await sync.mergeRemoteCategories(db, [
      {
        'id': 'c-1',
        'user': '7',
        'name': 'Coffee',
        'icon': 'cup',
        'color': '#000000',
        'type': 'expense',
      },
    ]);
    await sync.mergeRemoteCategories(db, [
      {
        'id': 'c-1',
        'user': '7',
        'name': 'Coffee & Tea',
        'icon': 'cup',
        'color': '#111111',
        'type': 'expense',
      },
    ]);

    final row = await category('c-1');
    expect(row['name'], 'Coffee & Tea');
    expect(row['color'], '#111111');
  });

  test('an unpushed custom category is not overwritten', () async {
    final local = await CatalogService().addCategory(
      name: 'Pets',
      type: TxnType.expense,
    );
    await sync.mergeRemoteCategories(db, [
      {'id': local.id, 'user': '7', 'name': 'Renamed', 'type': 'expense'},
    ]);

    final row = await category(local.id);
    expect(row['name'], 'Pets');
    expect(row['user_id'], 'local');
  });

  test('a rename clashing with another category is skipped', () async {
    Map<String, dynamic> owned(String id, String name) => {
      'id': id,
      'user': '7',
      'name': name,
      'type': 'expense',
    };
    await sync.mergeRemoteCategories(db, [
      owned('c-1', 'Coffee'),
      owned('c-2', 'Snacks'),
    ]);
    await sync.mergeRemoteCategories(db, [owned('c-2', 'Coffee')]);

    expect((await category('c-2'))['name'], 'Snacks');
  });

  test('subcategories are pulled; unknown categories are skipped', () async {
    final food = defaultCategories.first;
    await sync.mergeRemoteSubcategories(db, [
      {'id': '${food.id}:Snacks', 'category': food.id, 'name': 'Snacks'},
      {'id': 'missing:X', 'category': 'missing', 'name': 'X'},
    ]);

    final names = await db.query(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [food.id],
    );
    expect(names.map((r) => r['name']), contains('Snacks'));
    expect(await db.query('subcategories', where: "id = 'missing:X'"), isEmpty);
  });
}
