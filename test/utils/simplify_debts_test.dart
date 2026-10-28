import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/utils/simplify_debts.dart';

List<MemberBalance> balances(Map<int, double> byMember) => [
  for (final e in byMember.entries)
    MemberBalance(memberId: e.key, username: 'm${e.key}', balance: e.value),
];

/// Applying the plan must leave everyone at zero.
void expectSettles(Map<int, double> start, List<SuggestedPayment> plan) {
  final left = {for (final e in start.entries) e.key: (e.value * 100).round()};
  for (final p in plan) {
    final paise = (p.amount * 100).round();
    expect(paise, greaterThan(0));
    left[p.from] = left[p.from]! + paise;
    left[p.to] = left[p.to]! - paise;
  }
  expect(left.values.every((v) => v == 0), isTrue, reason: '$left');
}

void main() {
  test('nothing to do when everyone is settled', () {
    expect(simplifyDebts(balances({1: 0, 2: 0})), isEmpty);
  });

  test('two people: one payment', () {
    final plan = simplifyDebts(balances({1: 600, 2: -600}));
    expect(plan.single.from, 2);
    expect(plan.single.to, 1);
    expect(plan.single.amount, 600);
  });

  test('a chain of debts collapses to one payment', () {
    // A owes B 100 and B owes C 100: only A needs to pay C.
    final start = {1: -100.0, 2: 0.0, 3: 100.0};
    final plan = simplifyDebts(balances(start));
    expect(plan, hasLength(1));
    expect((plan.single.from, plan.single.to), (1, 3));
    expectSettles(start, plan);
  });

  test('n people never need more than n - 1 payments', () {
    final start = {1: 450.0, 2: -150.0, 3: -150.0, 4: -150.0, 5: 0.0};
    final plan = simplifyDebts(balances(start));
    expect(plan.length, lessThanOrEqualTo(4));
    expect(plan, hasLength(3));
    expectSettles(start, plan);
  });

  test('uneven thirds still settle to the paisa', () {
    // ₹100 split three ways leaves 33.33 / 33.33 / 33.34 shares.
    final start = {1: 66.67, 2: -33.33, 3: -33.34};
    final plan = simplifyDebts(balances(start));
    expectSettles(start, plan);
  });
}
