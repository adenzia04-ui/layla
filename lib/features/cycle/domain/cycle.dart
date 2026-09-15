import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

/// The prayer pause, as it is stored on `users/{uid}.cycle`.
///
/// A woman does not pray during menstruation, and those prayers are not made
/// up afterwards — there is no qada for them (Sahih Muslim 335). So the app
/// has to know when a pause is on, in order to stop asking her to pray, stop
/// nudging, stop marking anything missed, stop pausing her other apps, and
/// stop counting the days against a streak she has kept for months.
///
/// Knowing that is the most sensitive thing this app holds about anybody,
/// which is why it lives on the user document and the day documents and
/// nowhere else: those are the only places only their owner can read. Nothing
/// here ever reaches `progress/{uid}`, which friends fetch, or the widget
/// snapshot, which anyone who picks up the phone can read off a Lock Screen.
///
/// It is a day id rather than a timestamp because every other date in this app
/// is a day id, and because Home shows a count of days: doing that arithmetic
/// on instants gives a pause that reads "Day 3" in one time zone and "Day 2"
/// in another after a flight.
@immutable
class Cycle {
  const Cycle({this.startedOn});

  /// No pause on. The stored form is an absent or null `cycle` field.
  static const Cycle none = Cycle();

  /// After how many days the app may ask — once, gently — whether the pause
  /// has ended.
  ///
  /// **Not a ruling, and chosen so that it cannot be read as one.** The
  /// schools differ on the maximum: the Hanafis hold ten days, the Shafi'is,
  /// Hanbalis and Malikis fifteen. Asking on day eleven would tell a woman
  /// following any of the latter three, by the mere fact of asking, that she
  /// was past what is expected — the timing would be the ruling, whatever the
  /// wording said. Fifteen is past every one of them, so the question
  /// contradicts nobody. Nothing in this app ends a pause by itself: it ends
  /// when the bleeding stops and she has performed ghusl, and she is the only
  /// one who knows that.
  static const int askAfterDays = 15;

  /// How long the one question stays on screen once it has been asked.
  ///
  /// The contract is that the app may ask *once*. A question derived purely
  /// from the day count would instead sit on the Home card every time she
  /// opened the app, for as long as the pause ran — which reads as pressure to
  /// end something only she can end, in the one place a passer-by can see it.
  /// Two further days is long enough not to be missed and short enough to
  /// still be asking rather than nagging, and it needs no stored state.
  static const int askForDays = 2;

  /// The furthest back the catch-up will ever reach.
  ///
  /// A guard against a runaway write, not a statement about anybody's body: a
  /// pause still switched on after three months is an app somebody stopped
  /// using, and back-filling a year of documents to find that out helps no
  /// one.
  static const int maxCoveredDays = 90;

  /// "2026-09-15", the day the pause began. Null when none is on.
  final String? startedOn;

  /// Whether a pause is on. A malformed stored value counts as none, because
  /// the failure that matters here is the app inventing a pause nobody asked
  /// for.
  bool get isActive => Fmt.parseDayId(startedOn) != null;

  /// "Day 3" — the first day is 1, not 0, because that is how a person counts
  /// days and this number is shown to one.
  ///
  /// Zero when no pause is on. A [today] before the start day — a phone whose
  /// clock went backwards, or travel across the date line — still reads 1
  /// rather than zero or a negative: the pause has begun either way.
  int dayCount(DateTime today) {
    if (!isActive) return 0;
    final int? elapsed = Fmt.daysBetweenDayIds(startedOn, Fmt.dayId(today));
    if (elapsed == null || elapsed < 0) return 1;
    return elapsed + 1;
  }

  /// Whether the pause has run long enough that the app may ask about it, and
  /// is still inside the short window where asking once is asking rather than
  /// nagging. Asking is all it may ever do — see [askAfterDays].
  bool isLongerThanUsual(DateTime today) {
    final int days = dayCount(today);
    return days > askAfterDays && days <= askAfterDays + askForDays;
  }

  factory Cycle.fromMap(Map<String, Object?>? map) {
    if (map == null) return none;
    // Tested rather than cast. This decides whether the app asks a woman to
    // pray, and a cast that threw inside the profile stream would take every
    // screen that reads the profile down with it.
    final Object? started = map['startedOn'];
    return Cycle(startedOn: started is String ? started : null);
  }

  /// The stored shape, which `firestore.rules` holds to exactly this: the one
  /// key, or null for no pause at all.
  Map<String, Object?>? toMap() =>
      isActive ? <String, Object?>{'startedOn': startedOn} : null;

  @override
  bool operator ==(Object other) =>
      other is Cycle && other.startedOn == startedOn;

  @override
  int get hashCode => startedOn.hashCode;

  @override
  String toString() => 'Cycle(startedOn: $startedOn)';
}

/// Which days a pause covers, and which of them still need marking.
///
/// One definition, used by the repository that writes the days and by the
/// tests that check the streak survives them. Two definitions of "the days
/// this pause covers" would eventually disagree, and the disagreement would
/// show up as a broken streak weeks later.
abstract final class CycleDays {
  /// Every day id from the start of the pause to [today], inclusive.
  ///
  /// Empty when no pause is on. Capped at [Cycle.maxCoveredDays] — see there
  /// for why the cap is a write guard and not a claim about anybody.
  ///
  /// The cap is anchored at [today] and counts backwards, never forwards from
  /// the start. Anchored at the start it would keep the *oldest* ninety days,
  /// so from day ninety-one today itself would drop out of the list: nothing
  /// would mark it, `lastCompletedDate` would stop advancing, and two days
  /// later the streak the pause exists to protect would be gone with nothing
  /// on screen to explain it. Days that fall out behind the window were marked
  /// by earlier catch-ups while the pause was running, so nothing is left
  /// unrecorded.
  static List<String> covered(String? startedOn, DateTime today) {
    final DateTime? start = Fmt.parseDayId(startedOn);
    if (start == null) return const <String>[];

    final int? elapsed = Fmt.daysBetweenDayIds(startedOn, Fmt.dayId(today));
    if (elapsed == null || elapsed < 0) return <String>[startedOn!];

    final int first = elapsed < Cycle.maxCoveredDays
        ? 0
        : elapsed - Cycle.maxCoveredDays + 1;
    return <String>[
      for (int i = first; i <= elapsed; i++)
        Fmt.dayId(start.add(Duration(days: i))),
    ];
  }

  /// The covered days the catch-up still has to write.
  ///
  /// A day already excused needs nothing — that is what makes opening the app
  /// ten times in one day write once. Nor does a day already finished: all
  /// five were prayed before the pause began, the chain was carried by the
  /// completion itself, and overwriting it would erase a day she actually
  /// prayed.
  static List<String> needingMark({
    required String? startedOn,
    required DateTime today,
    required Set<String> alreadyExcused,
    required Set<String> alreadyComplete,
  }) => <String>[
    for (final String dateId in covered(startedOn, today))
      if (!alreadyExcused.contains(dateId) && !alreadyComplete.contains(dateId))
        dateId,
  ];
}
