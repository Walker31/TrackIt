import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/providers/group_provider.dart';
import 'package:trackit/widgets/wallet/events_section.dart';

/// Creating an event used to throw RangeError: while the new list's
/// balances loaded, FutureBuilder still handed out the old (shorter) list
/// of balances, and rows were matched to it by position.
void main() {
  Group group(int id, String name) =>
      Group(id: id, name: name, createdAt: DateTime(2026, 11, 19));

  Widget host(_FakeGroups provider) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        // The wallet screen rebuilds the section when the provider changes.
        child: ListenableBuilder(
          listenable: provider,
          builder: (_, _) => EventsSection(provider: provider, onCreate: () {}),
        ),
      ),
    ),
  );

  testWidgets('a new event while balances load does not throw', (tester) async {
    final provider = _FakeGroups([group(1, 'Goa trip')]);
    await tester.pumpWidget(host(provider));
    provider.answer(1, 300);
    await tester.pumpAndSettle();
    expect(find.text('Goa trip'), findsOneWidget);

    // A second event appears; its balance hasn't loaded yet.
    provider.setGroups([group(2, 'Flat'), group(1, 'Goa trip')]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Flat'), findsOneWidget);
    expect(find.text('Goa trip'), findsOneWidget);

    provider.answer(1, 300);
    provider.answer(2, -50);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('300'), findsWidgets);
  });

  testWidgets('removing an event while balances load does not throw', (
    tester,
  ) async {
    final provider = _FakeGroups([group(1, 'Goa trip'), group(2, 'Flat')]);
    await tester.pumpWidget(host(provider));
    provider.answer(1, 300);
    provider.answer(2, -50);
    await tester.pumpAndSettle();

    provider.setGroups([group(2, 'Flat')]);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Goa trip'), findsNothing);
    expect(find.text('Flat'), findsOneWidget);
  });
}

/// Groups and balances under the test's control; nothing touches a database.
class _FakeGroups extends ChangeNotifier implements GroupProvider {
  _FakeGroups(this._groups);

  List<Group> _groups;
  final _pending = <int, List<Completer<double>>>{};

  void setGroups(List<Group> groups) {
    _groups = groups;
    notifyListeners();
  }

  /// Completes every outstanding balance request for [groupId].
  void answer(int groupId, double balance) {
    for (final c in _pending.remove(groupId) ?? const <Completer<double>>[]) {
      c.complete(balance);
    }
  }

  @override
  List<Group> get groups => _groups;

  @override
  bool get isLoading => false;

  @override
  String? get currentUsername => 'me';

  @override
  Future<double> getMyBalance(int groupId) {
    final c = Completer<double>();
    _pending.putIfAbsent(groupId, () => []).add(c);
    return c.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
