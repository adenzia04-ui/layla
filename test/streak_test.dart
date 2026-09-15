import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/auth/domain/app_user.dart';

/// The stored streak only ever moved upward, on a finished day. Nothing pushed
/// it back down, so a broken chain kept reporting the number it reached.
void main() {
  final DateTime today = DateTime(2026, 8, 25, 14);
  String id(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  UserStats stats({int current = 3, String? last}) =>
      UserStats(currentStreak: current, lastCompletedDate: last);

  test('a day finished today keeps the streak', () {
    expect(stats(last: id(today)).streakOn(today), 3);
  });

  test('a day finished yesterday keeps it — today is still in progress', () {
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    expect(stats(last: id(yesterday)).streakOn(today), 3);
  });

  test('a gap of one whole day ends it', () {
    // Missed Dhuhr on the 24th, so the 24th never completed. The last finished
    // day is the 23rd and the chain is broken, whatever is stored.
    final DateTime twoDaysAgo = today.subtract(const Duration(days: 2));
    expect(
      stats(last: id(twoDaysAgo)).streakOn(today),
      0,
      reason: 'this is the case that used to keep showing 3 days',
    );
  });

  test('a long absence ends it', () {
    expect(
      stats(last: id(today.subtract(const Duration(days: 40)))).streakOn(today),
      0,
    );
  });

  test('no finished day ever means no streak', () {
    expect(stats(last: null).streakOn(today), 0);
    expect(stats(current: 0, last: id(today)).streakOn(today), 0);
  });

  test('it survives a month boundary', () {
    final DateTime firstOfMonth = DateTime(2026, 9, 1, 9);
    expect(
      stats(last: '2026-08-31').streakOn(firstOfMonth),
      3,
      reason: 'the 31st is yesterday, even though the month changed',
    );
  });
}
