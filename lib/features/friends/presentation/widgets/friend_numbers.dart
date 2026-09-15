import 'package:intl/intl.dart';

/// The small pieces of wording the friend card and the friend sheet share.
///
/// One place rather than two copies, so "1,240 prayers" on the card and
/// "1,240" on the sheet can never drift into different formats.
abstract final class FriendNumbers {
  static final NumberFormat _thousands = NumberFormat('#,##0');

  /// "1,240" — a running total, grouped so it can be read at a glance.
  static String count(int n) => _thousands.format(n);

  /// "1 day", "12 days", "1,000 days" — grouped the same way as [count], so
  /// a long streak reads like the totals beside it.
  static String days(int n) => n == 1 ? '1 day' : '${count(n)} days';

  /// "3 of 5 today".
  static String today(int completed) => '$completed of 5 today';

  /// "1 prayer together", "240 prayers together" — what two people have kept
  /// between them since they became friends.
  static String together(int n) =>
      n == 1 ? '1 prayer together' : '${count(n)} prayers together';

  /// "1 fast", "12 fasts" — a Ramadan tally.
  static String fasts(int n) => n == 1 ? '1 fast' : '$n fasts';

  /// "3 friends said MashaAllah" — the cheers on someone's own milestone.
  static String cheers(int n) =>
      n == 1 ? '1 friend said MashaAllah' : '$n friends said MashaAllah';

  /// "Day 12 of 40" — where a circle stands in its forty days.
  static String dayOf(int day, int days) => 'Day $day of $days';
}
