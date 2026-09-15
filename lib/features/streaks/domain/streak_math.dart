import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

/// The streak arithmetic, with no Firestore anywhere near it.
///
/// Lifted out of `PrayerDayRepository` so the rule that is easiest to get
/// wrong can be written down once and tested directly. Every transaction that
/// moves a streak goes through here, and so does `test/cycle_test.dart` — two
/// implementations of this would drift apart and only one of them would be the
/// one running on somebody's phone.
@immutable
class StreakStats {
  const StreakStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.lastConfirmedDate,
  });

  /// Reads the `stats` map off a user document. Missing is zero, not an error:
  /// a profile seeded by an older build is a profile with no streak yet.
  ///
  /// [lastConfirmedDate] falls back to [lastCompletedDate] only while the key
  /// has never been written. Before this app had a prayer pause the two were
  /// the same fact — nothing but a finished day ever moved the date — so an
  /// account that predates the field carries its last real completion there,
  /// and its friends' cards keep reading right through the upgrade. The test
  /// is on the key and not on its value, because every write that could move
  /// the two apart writes the key, null included: once a pause has touched the
  /// stats, the fallback must never fire again or it would hand the scoreboard
  /// the excused date this field exists to keep off it.
  factory StreakStats.fromMap(Map<String, Object?>? map) => StreakStats(
    currentStreak: (map?['currentStreak'] as num?)?.toInt() ?? 0,
    longestStreak: (map?['longestStreak'] as num?)?.toInt() ?? 0,
    lastCompletedDate: map?['lastCompletedDate'] is String
        ? map!['lastCompletedDate'] as String
        : null,
    lastConfirmedDate: map != null && map.containsKey('lastConfirmedDate')
        ? (map['lastConfirmedDate'] is String
              ? map['lastConfirmedDate'] as String
              : null)
        : (map?['lastCompletedDate'] is String
              ? map!['lastCompletedDate'] as String
              : null),
  );

  final int currentStreak;
  final int longestStreak;

  /// The last day the chain was carried — a completed day, or a day the
  /// prayer pause covered. "2026-08-20".
  ///
  /// This is the local streak's date and only the local streak's. It is what
  /// keeps a chain alive across a pause, which means that during one it says
  /// today while nothing at all was confirmed today — a pair no ordinary day
  /// can produce. Publishing it is therefore how the pause becomes legible
  /// from outside; [lastConfirmedDate] is the one a friend may be told.
  final String? lastCompletedDate;

  /// The last day all five prayers were actually confirmed. "2026-08-20".
  ///
  /// Written by the completion transaction and by nothing else — never by
  /// [afterExcusedDay]. That is the whole of its purpose: it is the half of
  /// [lastCompletedDate]'s meaning that is safe to publish, because it can only
  /// ever name a day on which the same scoreboard also reports five of five.
  /// A paused week leaves it frozen at the last real completion, so what
  /// friends see is a chain lapsing after two quiet days — field for field
  /// what they would see from somebody who simply did not open the app.
  ///
  /// The residual, stated rather than hidden: on the day she resumes and
  /// finishes, the friend-visible streak goes from 0 straight to twelve where
  /// an ordinary returning user's goes from 0 to one. Reading that needs
  /// somebody who memorised the old number, and it is the irreducible cost of
  /// a streak surviving the pause at all.
  final String? lastConfirmedDate;

  /// A day on which all five prayers were confirmed.
  ///
  /// The chain continues when the last carried day was yesterday, and starts
  /// again at one when it was longer ago than that.
  StreakStats afterCompletedDay(String dateId) {
    final String? yesterday = Fmt.dayIdBefore(dateId);
    final int next = switch (lastCompletedDate) {
      final String last when last == dateId => currentStreak, // counted already
      final String last when last == yesterday => currentStreak + 1,
      _ => 1,
    };
    return StreakStats(
      currentStreak: next,
      longestStreak: next > longestStreak ? next : longestStreak,
      lastCompletedDate: dateId,
      // The only place this ever moves. Five prayers were confirmed on this
      // day, so it is a day the scoreboard may name out loud.
      lastConfirmedDate: dateId,
    );
  }

  /// A day the prayer pause covers.
  ///
  /// **The invariant.** An excused day must neither break the chain nor
  /// lengthen it. Ten days prayed, six excused, then one more day prayed reads
  /// eleven — not one, and not seventeen.
  ///
  /// The mechanism is the date and nothing else. `currentStreak` is left
  /// exactly where it was, and `lastCompletedDate` is carried forward onto the
  /// excused day. That is what keeps `UserStats.streakOn` answering at all: it
  /// reports zero unless the last carried day is today or yesterday, so
  /// without the carry a week of pause would read as a week-long gap and the
  /// chain would be gone. And because the counter itself is untouched, the
  /// pause cannot invent a streak either — six excused days on an account that
  /// has never finished a day still read zero, and the next complete day
  /// continues from the number that was already there.
  ///
  /// Never backwards: a back-fill of an older day must not undo a more recent
  /// one, which is also what makes running the catch-up twice a no-op.
  StreakStats afterExcusedDay(String dateId) {
    final String? last = lastCompletedDate;
    final bool alreadyPast =
        last != null &&
        Fmt.parseDayId(last) != null &&
        last.compareTo(dateId) >= 0;
    if (alreadyPast) return this;

    // Carried only when the chain genuinely reaches the day before this one.
    // `currentStreak` in Firestore is never decayed — no Cloud Function runs
    // on this project, so a lapse nobody marked leaves a stale number behind
    // that `UserStats.streakOn` hides only because the date is old. Moving the
    // date forward un-hides it, and a woman who had not prayed for a week
    // would open the app on the first day of her pause and be handed back a
    // ten-day streak she did not keep. A pause may carry a chain; it may not
    // raise a dead one.
    final bool chainReachesHere = last == Fmt.dayIdBefore(dateId);
    return StreakStats(
      currentStreak: chainReachesHere ? currentStreak : 0,
      longestStreak: longestStreak,
      lastCompletedDate: dateId,
      // Deliberately untouched. Nothing was confirmed on this day.
      lastConfirmedDate: lastConfirmedDate,
    );
  }

  /// A prayer the user said outright they missed.
  ///
  /// `longestStreak` is a record of what was achieved and is left alone.
  /// `lastCompletedDate` is cleared so that tomorrow starts from one rather
  /// than continuing from a day whose chain is now broken — which is also why
  /// a pause followed by a missed day still breaks the chain: the pause only
  /// ever carried a date forward, and this drops it.
  StreakStats afterMissedDay() => StreakStats(
    currentStreak: 0,
    longestStreak: longestStreak,
    lastCompletedDate: null,
    // Left alone: missing a prayer today does not un-confirm a day that was
    // finished last week, and the friend-visible streak has already gone to
    // zero with `currentStreak`.
    lastConfirmedDate: lastConfirmedDate,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastCompletedDate': lastCompletedDate,
    'lastConfirmedDate': lastConfirmedDate,
  };

  @override
  bool operator ==(Object other) =>
      other is StreakStats &&
      other.currentStreak == currentStreak &&
      other.longestStreak == longestStreak &&
      other.lastCompletedDate == lastCompletedDate &&
      other.lastConfirmedDate == lastConfirmedDate;

  @override
  int get hashCode => Object.hash(
    currentStreak,
    longestStreak,
    lastCompletedDate,
    lastConfirmedDate,
  );

  @override
  String toString() =>
      'StreakStats(current: $currentStreak, longest: $longestStreak, '
      'last: $lastCompletedDate, confirmed: $lastConfirmedDate)';
}

/// What marking one day of the prayer pause actually has to write.
///
/// Lifted out of the transaction in `PrayerDayRepository.markExcused` for one
/// reason: the catch-up runs on every app open, so "opening the app ten times
/// in a day writes once and does not move the streak" is a property somebody
/// has to be able to check. Inside a Firestore transaction it is only
/// checkable against a live database; out here it is three booleans and a
/// test.
///
/// Deliberately knows nothing about [PrayerDay] or Firestore — it is handed
/// the two facts about the day that decide the answer.
@immutable
class ExcusedDayWrite {
  const ExcusedDayWrite._({required this.marksDay, required this.stats});

  /// Nothing to write. The day is already recorded and the chain already
  /// reaches it, which is what every run of the catch-up after the first one
  /// finds.
  static const ExcusedDayWrite nothing = ExcusedDayWrite._(
    marksDay: false,
    stats: null,
  );

  /// Whether the day document still needs the excused record.
  final bool marksDay;

  /// The stats to write, or null when the chain already reaches this day.
  ///
  /// Only ever [StreakStats.afterExcusedDay], which never raises
  /// `currentStreak` however many times this runs — the one thing it can do to
  /// the counter is drop it to zero, on a pause that began after a chain had
  /// already lapsed unremarked. See there.
  final StreakStats? stats;

  /// Whether the transaction can be skipped entirely.
  bool get isEmpty => !marksDay && stats == null;

  /// The write for [dateId], given what is already on the day and the profile.
  ///
  /// A day where all five were confirmed is left completely alone. It was
  /// prayed, the completion carried the chain itself, and overwriting it would
  /// erase a day she actually prayed to replace it with one she did not owe.
  factory ExcusedDayWrite.decide({
    required String dateId,
    required bool dayIsComplete,
    required bool dayIsExcused,
    required StreakStats stats,
  }) {
    if (dayIsComplete) return nothing;
    final StreakStats next = stats.afterExcusedDay(dateId);
    return ExcusedDayWrite._(
      marksDay: !dayIsExcused,
      stats: next == stats ? null : next,
    );
  }
}
