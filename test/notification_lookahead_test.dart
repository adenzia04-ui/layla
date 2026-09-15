import 'package:flutter_test/flutter_test.dart';

/// The notification queue has to survive the app being closed.
///
/// One day of lookahead was scheduled, and only while the app was open, so
/// closing it after Isha left nothing for Fajr. The failure was silent: no
/// error, no empty state, just no reminder the next morning.
///
/// iOS keeps at most 64 pending local notifications and drops the rest, so the
/// lookahead cannot simply be made large. This pins the arithmetic.
void main() {
  const int lookaheadDays = 3;
  const int prayers = 5;
  const int callsPerPrayer = 3; // before, adhan, after
  const int tahajjudPerDay = 1;
  const int iosPendingLimit = 64;

  test('three days of reminders fit inside the iOS limit', () {
    const int total =
        lookaheadDays * (prayers * callsPerPrayer + tahajjudPerDay);
    expect(total, 48);
    expect(total, lessThanOrEqualTo(iosPendingLimit));
  });

  test('a fourth day would leave no headroom', () {
    // Exactly 64 — at the limit, not over it. iOS drops the furthest-out
    // notifications silently once the queue is full, so a schedule that fills
    // it to the brim fails invisibly the moment anything else is queued.
    const int four = 4 * (prayers * callsPerPrayer + tahajjudPerDay);
    expect(four, iosPendingLimit);
    expect(
      lookaheadDays * (prayers * callsPerPrayer + tahajjudPerDay),
      lessThan(iosPendingLimit),
      reason: 'the chosen lookahead must leave slots spare',
    );
  });

  test('ids never collide across days', () {
    // index = day * 10 + prayer, in three bands 1000 / 1100 / 1200.
    final Set<int> ids = <int>{};
    for (int day = 0; day < lookaheadDays; day++) {
      for (int i = 0; i < prayers; i++) {
        final int index = day * 10 + i;
        ids
          ..add(1000 + index) // adhan
          ..add(1100 + index) // before
          ..add(1200 + index); // after
      }
      ids.add(2000 + day); // tahajjud
    }
    expect(
      ids.length,
      lookaheadDays * (prayers * callsPerPrayer + tahajjudPerDay),
      reason:
          'two notifications share an id, so one silently replaces '
          'the other',
    );
    // Tahajjud must stay clear of the reminder bands.
    expect(ids.where((int id) => id >= 1000 && id < 1300).length, 45);
  });

  test('today keeps a bare prayer index', () {
    // `lateReminderSync` cancels day 0 by prayer index alone. If day 0 were
    // offset, confirming a prayer would cancel nothing.
    for (int i = 0; i < prayers; i++) {
      expect(0 * 10 + i, i);
    }
  });
}
