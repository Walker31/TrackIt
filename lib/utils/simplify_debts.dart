import '../models/expenses.dart';

/// One payment in a settle-up plan: [from] pays [to] [amount].
class SuggestedPayment {
  final int from;
  final int to;
  final double amount;

  const SuggestedPayment(this.from, this.to, this.amount);

  @override
  String toString() => '$from → $to: $amount';
}

/// The fewest payments that settle everyone's net balance ("simplify
/// debts"). Who originally paid for what doesn't matter, only where each
/// person ends up: repeatedly, whoever owes the most pays whoever is owed
/// the most, as much as one of them needs. That settles at least one
/// person per payment, so n people need at most n - 1 payments.
///
/// Positive balance = owed money; negative = owes money (as in
/// [MemberBalance]). Amounts are rounded to paise.
List<SuggestedPayment> simplifyDebts(List<MemberBalance> balances) {
  // Work in paise so rounding can't leave ₹0.01 strays.
  final creditors = <(int, int)>[];
  final debtors = <(int, int)>[];
  for (final b in balances) {
    final paise = (b.balance * 100).round();
    if (paise > 0) creditors.add((b.memberId, paise));
    if (paise < 0) debtors.add((b.memberId, -paise));
  }

  final payments = <SuggestedPayment>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    creditors.sort((a, b) => b.$2.compareTo(a.$2));
    debtors.sort((a, b) => b.$2.compareTo(a.$2));
    final (creditor, owed) = creditors.first;
    final (debtor, owes) = debtors.first;
    final amount = owed < owes ? owed : owes;

    payments.add(SuggestedPayment(debtor, creditor, amount / 100));
    creditors[0] = (creditor, owed - amount);
    debtors[0] = (debtor, owes - amount);
    creditors.removeWhere((c) => c.$2 == 0);
    debtors.removeWhere((d) => d.$2 == 0);
  }
  return payments;
}
