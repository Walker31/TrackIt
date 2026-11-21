/// A UPI "pay me" link that any UPI app opens with the amount filled in.
/// [vpa] is the receiver's UPI ID (name@bank).
String upiLink({
  required String vpa,
  required String payeeName,
  required double amount,
  String? note,
}) {
  final params = {
    'pa': vpa.trim(),
    'pn': payeeName,
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    if (note != null && note.isNotEmpty) 'tn': note,
  };
  final query = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return 'upi://pay?$query';
}

/// Loose check for a UPI ID: something@handle, no spaces.
bool looksLikeUpiId(String v) => RegExp(
  r'^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9.-]{1,64}$',
).hasMatch(v.trim());

/// The message sent to someone who owes you, ready to paste anywhere.
String paymentRequestText({
  required String debtor,
  required String group,
  required String amount,
  String? link,
}) {
  final hi = debtor == 'Someone' ? 'Hi' : 'Hi $debtor';
  final pay = link == null ? '' : '\nPay with UPI: $link';
  return '$hi, you owe me $amount for "$group" on TrackIt.$pay';
}
