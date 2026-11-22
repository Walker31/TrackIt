import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/models/expenses.dart';
import 'package:trackit/utils/sms_parser.dart';

void main() {
  final now = DateTime(2026, 11, 22);
  ParsedSms? p(String s) => parseBankSms(s, now: now);

  test('UPI debit to a VPA', () {
    final r = p(
      'Rs.450.00 debited from A/c XX1234 on 20-11-26 to VPA swiggy@icici '
      '(UPI Ref No 432112345678). Not you? Call 1800...',
    )!;
    expect(r.amount, 450);
    expect(r.type, TxnType.expense);
    expect(r.merchant, 'Swiggy');
    expect(r.paymentMethod, PaymentMethod.upi);
    expect(r.date, DateTime(2026, 11, 20));
    expect(r.categoryName, 'Food & Dining');
  });

  test('card spend at a merchant, with balance after it', () {
    final r = p(
      'INR 1,249.50 spent on HDFC Bank Card x1234 at AMAZON PAY on '
      '2026-11-19:14:02:11. Avl bal: INR 52,301.00',
    )!;
    expect(r.amount, 1249.50);
    expect(r.merchant, 'Amazon Pay');
    expect(r.paymentMethod, PaymentMethod.card);
    expect(r.date, DateTime(2026, 11, 19));
    expect(r.categoryName, 'Shopping');
  });

  test('money sent to a person', () {
    final r = p(
      'Sent Rs.300.00 From HDFC Bank A/C *1234 To Ravi Kumar On 21/11/26 '
      'Ref 123456789',
    )!;
    expect(r.amount, 300);
    expect(r.type, TxnType.expense);
    expect(r.merchant, 'Ravi Kumar');
    expect(r.date, DateTime(2026, 11, 21));
  });

  test('salary credit', () {
    final r = p(
      'Your A/c XX5678 is credited with Rs 85,000.00 on 01-Nov-26 by NEFT '
      'from ACME SALARY. Avl Bal Rs 1,02,000.00',
    )!;
    expect(r.type, TxnType.income);
    expect(r.amount, 85000);
    expect(r.paymentMethod, PaymentMethod.netbanking);
    expect(r.date, DateTime(2026, 11, 1));
    expect(r.categoryName, 'Salary');
  });

  test('debit then credit to someone is a debit', () {
    final r = p(
      'Your a/c no. XXXXX1234 is debited for Rs.500.00 on 20-11-2026 and '
      'credited to a/c no. XXXXX9876 (IMPS Ref no 123)',
    )!;
    expect(r.type, TxnType.expense);
    expect(r.amount, 500);
    expect(r.paymentMethod, PaymentMethod.netbanking);
  });

  test('ATM withdrawal is cash', () {
    final r = p('Rs 2000 withdrawn at ATM S1AB2345 on 18-11-26.')!;
    expect(r.paymentMethod, PaymentMethod.cash);
    expect(r.amount, 2000);
  });

  test('OTPs, offers and text without money are ignored', () {
    expect(p('123456 is your OTP for a txn of Rs.999 at Amazon.'), isNull);
    expect(p('Hi, see you at 7'), isNull);
    expect(p('Rs 500 cashback upto on your next order!'), isNull);
  });

  test('future and impossible dates are dropped', () {
    expect(p('Rs.100 debited on 31-02-26')!.date, isNull);
    expect(p('Rs.100 debited on 25-12-26')!.date, isNull);
  });
}
