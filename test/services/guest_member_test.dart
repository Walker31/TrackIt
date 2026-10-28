import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackit/services/database_service.dart';
import 'package:trackit/services/group_service.dart';
import 'package:trackit/services/sync_service.dart';

/// Members without a TrackIt account ("guests") are added by name, pulled
/// with their guest flag, and pick up their account once linked.
void main() {
  late Database db;
  final sync = SyncService();

  Map<String, dynamic> group(List<Map<String, dynamic>> memberships) => {
    'id': 10,
    'client_id': 'g-10',
    'name': 'Goa trip',
    'icon': 'x',
    'memberships': memberships,
  };

  const owner = {'id': 100, 'user': 1, 'username': 'asha', 'role': 'owner'};

  setUp(() async {
    db = await DatabaseService.openInMemoryForTesting();
  });

  Future<Map<String, Object?>> member(int remoteId) async => (await db.query(
    'group_members',
    where: 'remote_id = ?',
    whereArgs: [remoteId],
  )).single;

  test('pulled guests keep their name and guest flag', () async {
    await sync.mergeRemoteGroups(db, [
      group([
        owner,
        {
          'id': 101,
          'user': null,
          'username': 'Ravi',
          'is_guest': true,
          'role': 'member',
        },
      ]),
    ]);

    final ravi = await member(101);
    expect(ravi['username'], 'Ravi');
    expect(ravi['is_guest'], 1);
    expect((await member(100))['is_guest'], 0);
  });

  test('a guest linked on another device turns into the account', () async {
    await sync.mergeRemoteGroups(db, [
      group([
        owner,
        {
          'id': 101,
          'user': null,
          'username': 'Ravi',
          'is_guest': true,
          'role': 'member',
        },
      ]),
    ]);
    await sync.mergeRemoteGroups(db, [
      group([
        owner,
        {
          'id': 101,
          'user': 7,
          'username': 'ravi_k',
          'is_guest': false,
          'role': 'member',
        },
      ]),
    ]);

    final ravi = await member(101);
    expect(ravi['username'], 'ravi_k');
    expect(ravi['user_id'], 7);
    expect(ravi['is_guest'], 0);
  });

  test('members rejected for having no account can become guests', () async {
    await sync.mergeRemoteGroups(db, [group([owner])]);
    final groupId = (await db.query('groups')).single['id'] as int;
    await db.insert('group_members', {
      'group_id': groupId,
      'username': 'Meera',
      'is_synced': 0,
      'sync_error': 'No user with that username exists.',
    });

    await GroupService().addRejectedAsGuests(groupId);

    final meera = (await db.query(
      'group_members',
      where: 'username = ?',
      whereArgs: ['Meera'],
    )).single;
    expect(meera['is_guest'], 1);
    expect(meera['sync_error'], isNull);
    expect(meera['is_synced'], 0);
    expect(await SyncService.pendingChanges(), greaterThan(0));
  });
}
