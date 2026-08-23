import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/formatters.dart';

void main() {
  group('Fmt.countdown', () {
    test('reads like the design: hours then minutes', () {
      expect(Fmt.countdown(const Duration(hours: 1, minutes: 10)), '1hr 10min');
      expect(Fmt.countdown(const Duration(hours: 2)), '2hr');
      expect(Fmt.countdown(const Duration(seconds: 48)), '48s');
    });

    test('ticks seconds below the hour, where they are what moves', () {
      expect(
        Fmt.countdown(const Duration(minutes: 32, seconds: 4)),
        '32min 04s',
      );
      expect(Fmt.countdown(const Duration(minutes: 32)), '32min 00s');
      // Past an hour, seconds would only add width to a number that changes
      // once a minute anyway.
      expect(
        Fmt.countdown(const Duration(hours: 1, minutes: 10, seconds: 30)),
        '1hr 10min',
      );
    });

    test('never shows a negative countdown', () {
      expect(Fmt.countdown(const Duration(minutes: -5)), 'now');
    });
  });

  group('Fmt.mmss', () {
    test('pads the focus-screen timer', () {
      expect(Fmt.mmss(const Duration(minutes: 28, seconds: 4)), '28:04');
      expect(Fmt.mmss(const Duration(seconds: 9)), '00:09');
      expect(Fmt.mmss(Duration.zero), '00:00');
      expect(Fmt.mmss(const Duration(seconds: -1)), '00:00');
    });
  });

  group('Fmt.dayId', () {
    test('is a stable Firestore document id', () {
      expect(Fmt.dayId(DateTime(2026, 8, 20, 23, 59)), '2026-08-20');
      expect(Fmt.dayId(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('Fmt.dayStart', () {
    test('strips the time so two moments on one day compare equal', () {
      expect(
        Fmt.dayStart(DateTime(2026, 8, 20, 3)),
        Fmt.dayStart(DateTime(2026, 8, 20, 21, 45)),
      );
    });
  });
}
