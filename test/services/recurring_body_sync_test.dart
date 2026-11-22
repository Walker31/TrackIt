import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/services/body_service.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/id_generator.dart';
import 'package:trackit/services/recurring_service.dart';
import 'package:trackit/services/sync_outbox.dart';
import 'package:trackit/services/sync_service.dart';

/// Recurring rules and body weight used to live only on the device.
void main() {
  late Database db;
  final sync = SyncService();

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<List<Map<String, Object?>>> outbox() => db.query(SyncOutbox.table);

  test('derived ids are RFC 4122 v5 and stable', () {
    // The RFC's DNS namespace example.
    expect(
      IdGenerator.derived(
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8',
        'www.example.com',
      ),
      '2ed6657d-e927-568b-95e1-2665a8aea6a2',
    );
    final rule = IdGenerator.uuid();
    expect(
      IdGenerator.derived(rule, '2026-11-05'),
      IdGenerator.derived(rule, '2026-11-05'),
    );
    expect(
      IdGenerator.derived(rule, '2026-11-05'),
      isNot(IdGenerator.derived(rule, '2026-12-05')),
    );
  });

  group('recurring rules', () {
    final service = RecurringService();

    RecurringRule rent({String? id, DateTime? next}) => RecurringRule(
      id: id ?? IdGenerator.uuid(),
      amount: 15000,
      type: TxnType.expense,
      category: ExpenseCategory.other,
      paymentMethod: PaymentMethod.upi,
      description: 'Rent',
      frequency: Frequency.monthly,
      anchorDay: 5,
      nextDate: next ?? DateTime(2026, 11, 5),
    );

    Map<String, dynamic> remote(
      int id,
      String clientId, {
      String nextDate = '2026-11-05',
      String amount = '15000.00',
      bool deleted = false,
    }) => {
      'id': id,
      'client_id': clientId,
      'amount': amount,
      'type': 'expense',
      'category': 'other',
      'category_id': null,
      'subcategory_id': null,
      'payment_method': 'upi',
      'description': 'Rent',
      'frequency': 'monthly',
      'anchor_day': 5,
      'next_date': nextDate,
      'end_date': null,
      'active': true,
      'is_deleted': deleted,
    };

    Future<Map<String, Object?>> row(String id) async => (await db.query(
      'recurring_rules',
      where: 'id = ?',
      whereArgs: [id],
    )).single;

    test('saving marks the rule unsynced and keeps its server id', () async {
      final r = rent();
      await service.save(r);
      expect((await row(r.id))['is_synced'], 0);

      await db.update('recurring_rules', {'remote_id': 7, 'is_synced': 1});
      await service.save(r.copyWith(amount: 16000));
      final now = await row(r.id);
      expect(now['remote_id'], 7);
      expect(now['is_synced'], 0);
      expect(now['amount'], 16000);
    });

    test('deleting a synced rule queues the server delete', () async {
      final r = rent();
      await service.save(r);
      await service.delete(r.id);
      expect(await outbox(), isEmpty, reason: 'never reached the server');

      await service.save(r);
      await db.update('recurring_rules', {'remote_id': 7, 'is_synced': 1});
      await service.delete(r.id);
      expect((await outbox()).single['path'], 'recurring-rules/7/');
      expect(await service.all(), isEmpty);
    });

    test(
      'pulled rules are inserted, edits taken, tombstones applied',
      () async {
        final cid = IdGenerator.uuid();
        await sync.mergeRemoteRecurringRules(db, [remote(1, cid)]);
        var r = (await service.all()).single;
        expect(r.id, cid, reason: 'the client id stays the local id');
        expect(r.amount, 15000);
        expect(r.nextDate, DateTime(2026, 11, 5));
        expect((await row(cid))['is_synced'], 1);

        await sync.mergeRemoteRecurringRules(db, [
          remote(1, cid, nextDate: '2026-12-05', amount: '16000'),
        ]);
        r = (await service.all()).single;
        expect(r.amount, 16000);
        expect(r.nextDate, DateTime(2026, 12, 5));

        await sync.mergeRemoteRecurringRules(db, [
          remote(1, cid, deleted: true),
        ]);
        expect(await service.all(), isEmpty);
      },
    );

    test('an unpushed local edit is not overwritten by a pull', () async {
      final cid = IdGenerator.uuid();
      await sync.mergeRemoteRecurringRules(db, [remote(1, cid)]);
      await service.save((await service.all()).single.copyWith(amount: 9000));
      await sync.mergeRemoteRecurringRules(db, [
        remote(1, cid, amount: '15500'),
      ]);
      expect((await service.all()).single.amount, 9000);
    });

    test('our own rule echoed back is linked, not duplicated', () async {
      final r = rent();
      await service.save(r);
      await sync.mergeRemoteRecurringRules(db, [remote(3, r.id)]);
      final rows = await db.query('recurring_rules');
      expect(rows, hasLength(1));
      expect(rows.single['remote_id'], 3);
      expect(rows.single['is_synced'], 0, reason: 'still needs its push');
    });

    group('two devices', () {
      final nov5 = DateTime(2026, 11, 5);
      final today = DateTime(2026, 11, 20);

      test('a device that pulled the advanced rule adds nothing', () async {
        // Device A adds November's rent and moves the rule to December.
        final r = rent(next: nov5);
        await service.save(r);
        expect(await service.addDue(now: today), 1);
        final a = await row(r.id);
        expect(a['next_date'], '2026-12-05');
        expect(a['is_synced'], 0, reason: 'the new next_date must upload');

        // Device B pulls the rule after A pushed it.
        db = await DatabaseService.openInMemoryForTesting();
        await sync.mergeRemoteRecurringRules(db, [
          remote(1, r.id, nextDate: '2026-12-05'),
        ]);
        expect(await service.addDue(now: today), 0);
        expect(await db.query('expenses'), isEmpty);
      });

      test('two devices adding the same period make the same entry', () async {
        final r = rent(next: nov5);
        await service.save(r);
        await service.addDue(now: today);
        final fromA = (await db.query('expenses')).single;

        // Device B pulled the rule before A's push landed.
        db = await DatabaseService.openInMemoryForTesting();
        await sync.mergeRemoteRecurringRules(db, [remote(1, r.id)]);
        await service.addDue(now: today);
        final fromB = (await db.query('expenses')).single;

        // Same client id: the server returns the first copy for the second
        // push, so only one rent payment exists.
        expect(fromB['uuid'], fromA['uuid']);
        expect(fromB['uuid'], r.entryUuid(nov5));
      });

      test('an entry already pulled from the other device is not added '
          'again', () async {
        final r = rent(next: nov5);
        await sync.mergeRemoteRecurringRules(db, [remote(1, r.id)]);
        // The transaction device A added arrived, but the rule is stale.
        await sync.mergeRemoteExpenses(db, [
          {
            'id': 50,
            'client_id': r.entryUuid(nov5),
            'amount': '15000.00',
            'type': 'expense',
            'txn_date': '2026-11-05',
            'note': 'Rent',
            'payment_method': 'upi',
          },
        ]);
        expect(await service.addDue(now: today), 0);
        expect(await db.query('expenses'), hasLength(1));
        expect((await row(r.id))['next_date'], '2026-12-05');
      });
    });
  });

  group('body weight', () {
    final body = BodyService();
    final day = DateTime(2026, 11, 20);

    Future<List<Map<String, Object?>>> rows() =>
        db.query('body_metrics', orderBy: 'date');

    Map<String, dynamic> remote(
      int id,
      String date, {
      String weight = '72.40',
      String? clientId,
      bool deleted = false,
    }) => {
      'id': id,
      'client_id': clientId ?? IdGenerator.uuid(),
      'date': date,
      'weight': weight,
      'is_deleted': deleted,
    };

    test('logging a day again updates it and keeps its server id', () async {
      await body.log(72.4, on: day);
      final first = (await rows()).single;
      expect(first['uuid'], isNotNull);
      expect(first['is_synced'], 0);

      await db.update('body_metrics', {'remote_id': 9, 'is_synced': 1});
      await body.log(72.0, on: day);
      final now = (await rows()).single;
      expect(now['uuid'], first['uuid']);
      expect(now['remote_id'], 9);
      expect(now['weight'], 72.0);
      expect(now['is_synced'], 0);
    });

    test('deleting a synced entry queues the server delete', () async {
      await body.log(72.4, on: day);
      await db.update('body_metrics', {'remote_id': 9, 'is_synced': 1});
      await body.delete(day);
      expect((await outbox()).single['path'], 'fitness/body-metrics/9/');
      expect(await rows(), isEmpty);
    });

    test('pulled entries are inserted and updated', () async {
      await sync.mergeRemoteBodyMetrics(db, [
        remote(1, '2026-11-19'),
        remote(2, '2026-11-20', weight: '72.1'),
      ]);
      expect((await body.entries()).map((e) => e.weight), [72.4, 72.1]);

      await sync.mergeRemoteBodyMetrics(db, [
        remote(2, '2026-11-20', weight: '71.8'),
      ]);
      expect((await body.entries()).last.weight, 71.8);
      expect(await rows(), hasLength(2));
    });

    test(
      'another device\'s entry for the same day replaces a synced one',
      () async {
        await sync.mergeRemoteBodyMetrics(db, [remote(1, '2026-11-20')]);
        await sync.mergeRemoteBodyMetrics(db, [
          remote(1, '2026-11-20', deleted: true),
          remote(2, '2026-11-20', weight: '71.0'),
        ]);
        final only = (await rows()).single;
        expect(only['remote_id'], 2);
        expect(only['weight'], 71.0);
      },
    );

    test('an unpushed local entry for the day wins', () async {
      await body.log(70.0, on: day);
      await sync.mergeRemoteBodyMetrics(db, [remote(5, '2026-11-20')]);
      final only = (await rows()).single;
      expect(only['weight'], 70.0);
      expect(only['remote_id'], isNull);

      await sync.mergeRemoteBodyMetrics(db, [
        remote(5, '2026-11-20', deleted: true),
      ]);
      expect(await rows(), hasLength(1), reason: 'tombstones skip dirty rows');
    });
  });

  test('pending changes count rules and body weight', () async {
    await RecurringService().save(
      RecurringRule.from(
        Expense(
          amount: 499,
          category: ExpenseCategory.entertainment,
          timestamp: DateTime(2026, 11, 1),
        ),
        Frequency.monthly,
      ),
    );
    await BodyService().log(72.4, on: DateTime(2026, 11, 20));
    final pending = await SyncService.pendingByKind();
    expect(pending['Recurring'], 1);
    expect(pending['Body weight'], 1);
  });
}
