import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/prayer_times/domain/prayer_settings.dart';

/// The onboarding tells people Layla Pro will call three times for every prayer.
/// Before this, it called once — at the adhan — and there was no setting for
/// anything else. These pin the promise down.
void main() {
  test('three calls are on by default, at 10 before and 30 after', () {
    const PrayerSettings s = PrayerSettings();
    expect(s.remindBefore, isTrue);
    expect(s.beforeMinutes, 10);
    expect(s.remindAfter, isTrue);
    expect(s.afterMinutes, 30);
  });

  test('the offered choices match the settings screen', () {
    expect(PrayerSettings.beforeChoices, <int>[5, 10, 15]);
    expect(PrayerSettings.afterChoices, <int>[15, 30, 45]);
  });

  test('minutes survive a round trip', () {
    const PrayerSettings s = PrayerSettings(
      beforeMinutes: 15,
      afterMinutes: 45,
      remindBefore: false,
    );
    final PrayerSettings back = PrayerSettings.fromMap(s.toMap());
    expect(back.beforeMinutes, 15);
    expect(back.afterMinutes, 45);
    expect(back.remindBefore, isFalse);
    expect(back.remindAfter, isTrue);
  });

  test('a value the screen cannot show falls back to the default', () {
    // An older build, or a hand-edited document, must not leave a reminder
    // scheduled at some minute the settings screen has no chip for — there
    // would be no way to see it or undo it.
    final PrayerSettings odd = PrayerSettings.fromMap(const <String, Object?>{
      'beforeMinutes': 7,
      'afterMinutes': 999,
    });
    expect(odd.beforeMinutes, 10);
    expect(odd.afterMinutes, 30);
  });
}
