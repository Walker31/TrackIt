import 'package:flutter_test/flutter_test.dart';
import 'package:trackit/utils/payment_request.dart';
import 'package:trackit/widgets/onboarding.dart';

void main() {
  test('UPI link encodes the payee, amount and note', () {
    final link = upiLink(
      vpa: ' asha@okbank ',
      payeeName: 'Asha K',
      amount: 450,
      note: 'Goa trip',
    );
    expect(
      link,
      'upi://pay?pa=asha%40okbank&pn=Asha%20K&am=450.00&cu=INR&tn=Goa%20trip',
    );
  });

  test('UPI ID check', () {
    expect(looksLikeUpiId('asha@okbank'), isTrue);
    expect(looksLikeUpiId('98765.43210@upi'), isTrue);
    expect(looksLikeUpiId('asha'), isFalse);
    expect(looksLikeUpiId('as ha@bank'), isFalse);
  });

  test('request text names the person and includes the link', () {
    final text = paymentRequestText(
      debtor: 'Ravi',
      group: 'Flat',
      amount: '₹300',
      link: 'upi://pay?pa=x%40y',
    );
    expect(text, startsWith('Hi Ravi, you owe me ₹300 for "Flat"'));
    expect(text, contains('upi://pay?pa=x%40y'));
    expect(
      paymentRequestText(debtor: 'Ravi', group: 'Flat', amount: '₹300'),
      isNot(contains('UPI')),
    );
  });

  test('starter splits use library exercises with muscle groups', () {
    for (final split in starterSplits) {
      for (final routine in split.toRoutines()) {
        expect(routine.exercises, isNotEmpty);
        for (final e in routine.exercises) {
          expect(e.muscleGroup, isNotEmpty, reason: '${e.name} not in library');
        }
      }
    }
  });
}
