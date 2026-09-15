import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seven percent of every subscription is set aside for charity. This is the
/// running total, kept in one public Firestore document — `public/charity` —
/// so every phone shows the same number the moment it changes.
///
/// The document is written from the Firebase console (or, later, a Cloud
/// Function fed by App Store sales), never by the app: a phone can only read
/// it. Fields: `raised` (number), `target` (number), `currency` (string, "USD"),
/// `note` (string, optional — a line about where the last amount went).
@immutable
class CharityFund {
  const CharityFund({
    this.raised = 0,
    this.target = 2000,
    this.currency = 'USD',
    this.note,
  });

  final double raised;
  final double target;
  final String currency;
  final String? note;

  double get fraction => target <= 0 ? 0 : (raised / target).clamp(0.0, 1.0);

  /// "$1,240" — whole units, grouped, with the sign for the currency.
  String money(double v) {
    final String sign = switch (currency) {
      'USD' => '\$',
      'GBP' => '£',
      'EUR' => '€',
      'MYR' => 'RM ',
      _ => '$currency ',
    };
    final String digits = v.round().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '$sign$out';
  }

  static CharityFund fromDoc(Map<String, dynamic>? d) {
    if (d == null) return const CharityFund();
    return CharityFund(
      raised: (d['raised'] as num?)?.toDouble() ?? 0,
      target: (d['target'] as num?)?.toDouble() ?? 2000,
      currency: d['currency'] as String? ?? 'USD',
      note: d['note'] as String?,
    );
  }
}

/// Live: updates on every phone as soon as the document changes. Any error
/// (offline, Firebase not set up in a test) shows the empty bar rather than
/// an error.
final StreamProvider<CharityFund> charityFundProvider =
    StreamProvider<CharityFund>((Ref ref) {
      try {
        return FirebaseFirestore.instance
            .doc('public/charity')
            .snapshots()
            .map(
              (DocumentSnapshot<Map<String, dynamic>> s) =>
                  CharityFund.fromDoc(s.data()),
            )
            .handleError((Object e) {
              debugPrint('Layla Pro: charity fund unavailable ($e)');
            });
      } catch (e) {
        debugPrint('Layla Pro: charity fund unavailable ($e)');
        return Stream<CharityFund>.value(const CharityFund());
      }
    });
