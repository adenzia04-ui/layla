import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/features/friends/application/friends_controller.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/prayer_times/application/prayer_times_controller.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/application/streak_controller.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';

/// The scoreboard, with no Firestore anywhere near it.
///
/// Everything here is about the two moments a progress document is read or
/// written: what a friend's phone makes of the fields it was handed, and what
/// this phone puts in them. Both matter more than they look. A friend's phone
/// re-derives the streak from the calendar, so a stale document must not go on
/// showing a chain that has lapsed; and a publish the rules refuse is silent,
/// so a value past a ceiling does not fail loudly — it freezes the scoreboard
/// every friend sees at whatever it last held.
void main() {
  String id(DateTime d) => Fmt.dayId(d);

  FriendProgress progress({
    String uid = 'u1',
    String name = 'Amira Khan',
    String code = 'ABC234',
    int streak = 0,
    int longestStreak = 0,
    int totalPrayers = 0,
    int totalTahajjud = 0,
    int todayCompleted = 0,
    String todayDate = '',
    String? lastCompletedDate,
    DateTime? updatedAt,
  }) => FriendProgress(
    uid: uid,
    name: name,
    code: code,
    streak: streak,
    longestStreak: longestStreak,
    totalPrayers: totalPrayers,
    totalTahajjud: totalTahajjud,
    todayCompleted: todayCompleted,
    todayDate: todayDate,
    lastCompletedDate: lastCompletedDate,
    updatedAt: updatedAt,
  );

  // `streakToday` and `prayedToday` read the real clock rather than taking a
  // `now`, so the dates here are built from it too. Fmt.dayId of DateTime.now()
  // is what the widgets compare against on a real phone.
  group('FriendProgress.streakToday', () {
    final DateTime now = DateTime.now();

    test('a day finished today keeps the streak', () {
      expect(progress(streak: 7, lastCompletedDate: id(now)).streakToday, 7);
    });

    test('a day finished yesterday keeps it — today is still in progress', () {
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      expect(
        progress(streak: 7, lastCompletedDate: id(yesterday)).streakToday,
        7,
      );
    });

    test('two days ago is a broken chain, whatever was published', () {
      final DateTime twoDaysAgo = now.subtract(const Duration(days: 2));
      expect(
        progress(streak: 7, lastCompletedDate: id(twoDaysAgo)).streakToday,
        0,
        reason: 'a friend who stopped opening the app keeps no streak',
      );
    });

    test('a friend who has never finished a day has no streak', () {
      expect(progress(streak: 7).streakToday, 0);
    });

    test('a stored zero stays zero even on a finished day', () {
      expect(progress(lastCompletedDate: id(now)).streakToday, 0);
    });
  });

  group('FriendProgress.prayedToday', () {
    final DateTime now = DateTime.now();

    test('today\'s date with a tally counts', () {
      expect(
        progress(todayCompleted: 3, todayDate: id(now)).prayedToday,
        isTrue,
      );
    });

    test('yesterday\'s tally is not today\'s', () {
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      expect(
        progress(todayCompleted: 5, todayDate: id(yesterday)).prayedToday,
        isFalse,
        reason: 'yesterday\'s five shown as today\'s would be a small lie',
      );
    });

    test('today with nothing prayed yet is not prayed', () {
      expect(progress(todayDate: id(now)).prayedToday, isFalse);
    });
  });

  group('FriendProgress.initials', () {
    test('one word gives one letter', () {
      expect(progress(name: 'amira').initials, 'A');
    });

    test('two words give two, uppercased', () {
      expect(progress(name: 'amira khan').initials, 'AK');
    });

    test('extra whitespace is not a third name', () {
      expect(progress(name: '  Amira   Khan  ').initials, 'AK');
      expect(progress(name: 'Muhammad Abdurrahman Al-Kindi').initials, 'MA');
    });

    test('a blank name gives the placeholder rather than throwing', () {
      expect(progress(name: '').initials, '?');
      expect(progress(name: '   ').initials, '?');
    });
  });

  group('FriendProgress.fromDoc', () {
    test('round trips everything a friend sees', () {
      final DateTime updatedAt = DateTime(2026, 9, 14, 21, 30);
      final FriendProgress sent = progress(
        uid: 'them',
        name: 'Yusuf Adeyemi',
        code: 'DEF345',
        streak: 12,
        longestStreak: 30,
        totalPrayers: 1240,
        totalTahajjud: 312,
        todayCompleted: 3,
        todayDate: '2026-09-14',
        lastCompletedDate: '2026-09-13',
      );

      // The document as Firestore would hold it: the map the publisher writes,
      // plus the server stamp toMap deliberately leaves out.
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          ...sent.toMap(),
          'updatedAt': Timestamp.fromDate(updatedAt),
        }),
      );

      expect(back.uid, 'them', reason: 'the uid is the document id');
      expect(back.name, sent.name);
      expect(back.code, sent.code);
      expect(back.streak, sent.streak);
      expect(back.longestStreak, sent.longestStreak);
      expect(back.totalPrayers, sent.totalPrayers);
      expect(back.totalTahajjud, sent.totalTahajjud);
      expect(back.todayCompleted, sent.todayCompleted);
      expect(back.todayDate, sent.todayDate);
      expect(back.lastCompletedDate, sent.lastCompletedDate);
      expect(back.updatedAt, updatedAt);
    });

    test('a document from an older build reads as zeros, not as null', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{'code': 'DEF345'}),
      );

      expect(back.name, FriendName.fallback, reason: 'never a blank name');
      expect(back.code, 'DEF345');
      expect(back.streak, 0);
      expect(back.longestStreak, 0);
      expect(back.totalPrayers, 0);
      expect(back.totalTahajjud, 0);
      expect(back.todayCompleted, 0);
      expect(back.todayDate, '');
      expect(back.lastCompletedDate, isNull);
      expect(back.updatedAt, isNull);
      expect(back.streakToday, 0);
      expect(back.prayedToday, isFalse);
    });

    test('an empty document does not throw', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', const <String, Object?>{}),
      );
      expect(back.uid, 'them');
      expect(back.code, '');
      expect(back.totalPrayers, 0);
    });

    test('counters stored as doubles still read as ints', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          'streak': 12.0,
          'totalPrayers': 1240.0,
        }),
      );
      expect(back.streak, 12);
      expect(back.totalPrayers, 1240);
    });
  });

  // What this phone publishes, built by the real provider rather than by a
  // copy of its arithmetic. Every value below is one firestore.rules would
  // refuse if it came through unclamped, and a refusal is swallowed: friends
  // would simply be left looking at the last scoreboard that did land.
  group('myProgressProvider clamps to what the rules take', () {
    final DateTime today = DateTime(2026, 9, 14);
    final String todayId = Fmt.dayId(today);

    PrayerDay dayWith(int completed, {String? dateId}) => PrayerDay(
      dateId: dateId ?? todayId,
      records: <PrayerId, PrayerRecord>{
        for (final PrayerId id in PrayerId.obligatory.take(completed))
          id: const PrayerRecord(status: PrayerStatus.completed),
      },
    );

    Future<FriendProgress?> published(
      UserStats stats, {
      PrayerDay? day,
      String name = 'Amira Khan',
      String? photo,
      String? photoThumb,
      // Which day the phone thinks it is. A leak that only opens on the second
      // day of a pause cannot be seen from a single snapshot.
      DateTime? on,
    }) async {
      final DateTime when = on ?? today;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          friendsUidProvider.overrideWithValue('me'),
          myFriendCodeProvider.overrideWith((Ref ref) async => 'ABC234'),
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              AppUser(
                uid: 'me',
                displayName: name,
                email: 'amira@example.com',
                photo: photo,
                photoThumb: photoThumb,
                stats: stats,
              ),
            ),
          ),
          todayProvider.overrideWithValue(when),
          todayPrayerDayProvider.overrideWith(
            (Ref ref) => Stream<PrayerDay>.value(
              day ?? dayWith(3, dateId: Fmt.dayId(when)),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Every async dependency settled before the scoreboard is read; the
      // provider hands back null while any of them is still loading.
      await container.read(myFriendCodeProvider.future);
      await container.read(appUserProvider.future);
      await container.read(todayPrayerDayProvider.future);
      return container.read(myProgressProvider);
    }

    test('ordinary stats pass through untouched', () async {
      final FriendProgress? p = await published(
        const UserStats(
          currentStreak: 12,
          longestStreak: 30,
          totalPrayers: 1240,
          totalTahajjud: 312,
          lastCompletedDate: '2026-09-13',
          lastConfirmedDate: '2026-09-13',
        ),
      );

      expect(p, isNotNull);
      expect(p!.streak, 12);
      expect(p.longestStreak, 30);
      expect(p.totalPrayers, 1240);
      expect(p.totalTahajjud, 312);
      expect(p.todayCompleted, 3);
      expect(p.todayDate, todayId);
      expect(p.lastCompletedDate, '2026-09-13');
      expect(p.name, 'Amira Khan');
      expect(p.code, 'ABC234');
    });

    test('a longest streak behind the current one is lifted to it', () async {
      // A real state, not a contrived one: `longestStreak` is only ever raised
      // by the recalculation that this plan does not run, so a phone that has
      // counted past it sits here for good. The rules demand
      // longestStreak >= streak, so publishing it as stored would refuse every
      // write from this account from then on.
      final FriendProgress? p = await published(
        const UserStats(
          currentStreak: 9,
          longestStreak: 2,
          lastCompletedDate: '2026-09-13',
        ),
      );

      expect(p!.streak, 9);
      expect(
        p.longestStreak,
        greaterThanOrEqualTo(p.streak),
        reason: 'the rules refuse a longest streak behind the current one',
      );
      expect(p.longestStreak, 9);
    });

    test('an absurd counter is cut to the ceiling, not sent', () async {
      final FriendProgress? p = await published(
        const UserStats(
          currentStreak: 999999999,
          longestStreak: 5,
          totalPrayers: 9007199254740991,
          totalTahajjud: 123456789,
          lastCompletedDate: '2026-09-13',
        ),
      );

      expect(p!.streak, FriendProgress.maxStreak);
      expect(p.longestStreak, FriendProgress.maxStreak);
      expect(p.longestStreak, greaterThanOrEqualTo(p.streak));
      expect(p.totalPrayers, FriendProgress.maxTotalPrayers);
      expect(p.totalTahajjud, FriendProgress.maxTotalTahajjud);
    });

    test('a negative counter never goes out below zero', () async {
      final FriendProgress? p = await published(
        const UserStats(
          currentStreak: -4,
          longestStreak: -9,
          totalPrayers: -1,
          totalTahajjud: -1,
        ),
      );

      expect(p!.streak, 0);
      expect(p.longestStreak, 0);
      expect(p.totalPrayers, 0);
      expect(p.totalTahajjud, 0);
    });

    test('every field it builds is one the rules would take', () async {
      for (final UserStats stats in <UserStats>[
        const UserStats(),
        const UserStats(currentStreak: 9, longestStreak: 2),
        const UserStats(
          currentStreak: 999999999,
          totalPrayers: 999999999,
          totalTahajjud: 999999999,
        ),
        const UserStats(
          currentStreak: -4,
          longestStreak: -4,
          totalPrayers: -4,
          totalTahajjud: -4,
        ),
      ]) {
        final FriendProgress p = (await published(stats, day: dayWith(5)))!;
        expect(p.streak, inInclusiveRange(0, FriendProgress.maxStreak));
        expect(
          p.longestStreak,
          inInclusiveRange(p.streak, FriendProgress.maxStreak),
        );
        expect(
          p.totalPrayers,
          inInclusiveRange(0, FriendProgress.maxTotalPrayers),
        );
        expect(
          p.totalTahajjud,
          inInclusiveRange(0, FriendProgress.maxTotalTahajjud),
        );
        expect(p.todayCompleted, inInclusiveRange(0, 5));
        expect(FriendProgress.dayIdPattern.hasMatch(p.todayDate), isTrue);
        expect(p.name.runes.length, inInclusiveRange(1, FriendName.maxLength));
      }
    });

    test('a name too long for the rules is cut before it goes out', () async {
      final FriendProgress? p = await published(
        const UserStats(),
        name: 'a' * 80,
      );
      expect(p!.name.length, FriendName.maxLength);
    });

    test('a last completed date in an older shape is dropped', () async {
      final FriendProgress? p = await published(
        const UserStats(
          currentStreak: 3,
          lastCompletedDate: '14/09/2026',
          lastConfirmedDate: '14/09/2026',
        ),
      );
      expect(
        p!.lastCompletedDate,
        isNull,
        reason: 'the rules take null or a day id, nothing else',
      );
    });

    /// The scoreboard must not make a prayer pause legible.
    ///
    /// The three obvious keys — `cycle`, `gender`, `excused` — are refused by
    /// `firestore.rules`, and that is the easy half. The hard half is that the
    /// fields which were always allowed must not start moving differently
    /// during a pause, because a friend holding two scoreboards can read a
    /// difference just as well as a new field.
    ///
    /// The one that does is the stored `lastCompletedDate`. An excused day
    /// carries the chain by setting it to that day — which is what keeps the
    /// streak alive — while `todayCompleted` stays 0. For anybody else those
    /// two can never hold that combination at once: the only thing that sets
    /// the date to today is finishing all five, and then the count reads 5.
    ///
    /// Which is why what goes out is `lastConfirmedDate`, a field only the
    /// completion transaction ever moves. One snapshot is not enough to check
    /// that: a fabricated "yesterday" also passes on day one, and only starts
    /// lying on day two, when yesterday was itself paused. So the assertions
    /// below run a pause and an absence side by side across a week.
    group('a pause is not legible on the scoreboard', () {
      /// A day the pause covers, as the repository leaves it: excused records,
      /// and the day itself flagged.
      PrayerDay excusedOn(String dateId) => PrayerDay(
        dateId: dateId,
        excused: true,
        records: <PrayerId, PrayerRecord>{
          for (final PrayerId id in PrayerId.obligatory)
            id: const PrayerRecord(status: PrayerStatus.excused),
        },
      );

      /// The last day she actually finished, the evening before the pause.
      const String lastReal = '2026-09-13';

      /// Her stats on day [n] of the pause. The chain is carried onto each
      /// excused day in turn, so the stored date advances daily — and the
      /// confirmed date does not move at all.
      UserStats pausedStats(String dayId) => UserStats(
        currentStreak: 11,
        longestStreak: 11,
        totalPrayers: 1240,
        lastCompletedDate: dayId,
        lastConfirmedDate: lastReal,
      );

      /// Somebody with the same streak behind them who simply stopped opening
      /// the app after the thirteenth.
      const UserStats quietStats = UserStats(
        currentStreak: 11,
        longestStreak: 11,
        totalPrayers: 1240,
        lastCompletedDate: lastReal,
        lastConfirmedDate: lastReal,
      );

      test('publishes no completed prayers, like any unprayed day', () async {
        final FriendProgress? p = await published(
          pausedStats(todayId),
          day: excusedOn(todayId),
        );

        expect(p!.todayCompleted, 0);
        expect(p.streak, 11, reason: 'the chain is carried, not broken');
      });

      test('does not publish a completed date today has not earned', () async {
        // The leak, stated on its own. A date of today next to a count of zero
        // is a state no ordinary day can produce, so publishing it tells a
        // friend exactly what this feature exists to keep private.
        final FriendProgress? p = await published(
          pausedStats(todayId),
          day: excusedOn(todayId),
        );

        expect(
          p!.lastCompletedDate,
          isNot(todayId),
          reason:
              'today, with nothing confirmed today, happens on no other kind '
              'of day',
        );
      });

      test('a paused week publishes what a quiet week publishes, day for '
          'day', () async {
        // The whole promise, and the reason it takes a loop. A publisher that
        // merely refuses to name today passes the single-snapshot version of
        // this test and fails here at day two: the substituted "yesterday"
        // advances with the calendar, so the friend-visible chain stays alive
        // week after week beside a tally of zero — a pair no account that is
        // not paused can produce, and one a friend reads straight off the
        // stock card as "11 days, 0 of 5 today" two evenings running.
        for (int i = 0; i < 6; i++) {
          final DateTime when = today.add(Duration(days: i));
          final String dayId = Fmt.dayId(when);
          final String which = 'day ${i + 1} of the pause ($dayId)';

          final FriendProgress? paused = await published(
            pausedStats(dayId),
            day: excusedOn(dayId),
            on: when,
          );
          final FriendProgress? quiet = await published(
            quietStats,
            day: PrayerDay(dateId: dayId),
            on: when,
          );

          expect(paused!.toMap(), quiet!.toMap(), reason: which);
          expect(
            paused.streakOn(when),
            quiet.streakOn(when),
            reason: 'the live streak a friend computes, $which',
          );
        }
      });

      test(
        'her own streak is untouched by what the scoreboard withholds',
        () async {
          // The other half of the bargain. Splitting the two dates must not cost
          // her the streak on her own phone — that reads the carried date, and
          // the carried date is what a pause moves.
          for (int i = 0; i < 6; i++) {
            final DateTime when = today.add(Duration(days: i));
            expect(pausedStats(Fmt.dayId(when)).streakOn(when), 11);
          }
        },
      );

      test('a day that really was finished still publishes today', () async {
        final FriendProgress? p = await published(
          UserStats(
            currentStreak: 12,
            lastCompletedDate: todayId,
            lastConfirmedDate: todayId,
          ),
          day: dayWith(PrayerId.obligatory.length),
        );

        expect(p!.lastCompletedDate, todayId);
        expect(p.todayCompleted, PrayerId.obligatory.length);
      });

      test(
        'on the first day it still reads as an ordinary quiet morning',
        () async {
          // The reason the fix cannot simply drop the field: friends compute the
          // streak from it on their own phones, and on day one a paused chain
          // has to read exactly as alive as anybody else's before Fajr.
          final FriendProgress? paused = await published(
            pausedStats(todayId),
            day: excusedOn(todayId),
          );

          expect(paused!.streakOn(today), 11);
        },
      );
    });

    test('nothing is published for yesterday\'s day document', () async {
      // At the rollover the day stream still hands out yesterday's document
      // while it rebuilds. Publishing it would file yesterday's five under
      // today's date on every friend's screen.
      final FriendProgress? p = await published(
        const UserStats(currentStreak: 3),
        day: dayWith(5, dateId: '2026-09-13'),
      );
      expect(p, isNull);
    });

    // Which of the two stored pictures goes onto the scoreboard.
    //
    // This is the one field where picking the wrong one is invisible until it
    // is everybody's problem. `users/{uid}.photo` is allowed 200000 characters
    // and `progress/{uid}.photo` only 64000, so publishing the big copy is a
    // write the rules refuse — and the publisher swallows a refusal, so every
    // friend's scoreboard would simply stop moving, with nothing on any screen
    // to say why. Nothing else in the suite would have caught it.
    group('the picture it publishes', () {
      // Sized like the real ones rather than at their ceilings: a 512-pixel
      // crop encodes to roughly this, and its 128-pixel copy to roughly that.
      final String big = 'A' * 128000;
      final String small = 'B' * 6000;

      test('is the small copy, never the big one', () async {
        final FriendProgress? p = await published(
          const UserStats(),
          photo: big,
          photoThumb: small,
        );

        expect(p!.photo, small);
        expect(
          p.photo!.length,
          lessThanOrEqualTo(FriendProgress.maxPhotoChars),
          reason: 'the rules refuse a published picture past this, silently',
        );
      });

      test('falls back to the old one on an account from before the crop '
          'editor', () async {
        // Their picture was stored under the old 256-pixel build, so there is
        // no thumbnail to publish and nothing to make one from. Publishing
        // null instead would turn a face their friends have seen for weeks
        // back into initials on the day this shipped.
        final String legacy = 'C' * 40000;
        final FriendProgress? p = await published(
          const UserStats(),
          photo: legacy,
        );

        expect(p!.photo, legacy);
      });

      test('drops an old picture the scoreboard would refuse', () async {
        // The fallback above is only safe while it stays under the published
        // ceiling. A big new-style photo with no thumbnail beside it — a
        // half-written profile — must publish nothing rather than a write
        // that freezes the scoreboard.
        final FriendProgress? p = await published(
          const UserStats(),
          photo: big,
        );

        expect(p!.photo, isNull);
      });

      test('is null when the picture has been removed', () async {
        // `AvatarController.remove` nulls both fields on the profile; this is
        // what the scoreboard then publishes. The key is still in `toMap`, so
        // the publisher sees a change and sends it — a picture taken off has
        // to reach friends as surely as one put on.
        final FriendProgress? p = await published(const UserStats());

        expect(p!.photo, isNull);
        expect(p.toMap().containsKey('photo'), isTrue);
      });
    });

    test('a guest publishes nothing at all', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[friendsUidProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      expect(container.read(myProgressProvider), isNull);
    });
  });
}

// ignore: subtype_of_sealed_class
/// The one thing `fromDoc` actually reads: an id and a map.
///
/// A real `DocumentSnapshot` cannot be built without Firestore, and the rest
/// of its surface is never touched here — so it is left to `noSuchMethod`,
/// which throws loudly if this test ever starts leaning on it.
///
/// `DocumentSnapshot` is sealed so that nobody writes a second Firestore; the
/// point of the seal is the production code, and this stand-in exists only so
/// the reader of a real document can be tested without one. The alternative —
/// testing a hand-written copy of `fromDoc` instead — would check a
/// reimplementation rather than the function friends' phones actually run.
class _FakeDoc implements DocumentSnapshot<Map<String, Object?>> {
  _FakeDoc(this.id, this._data);

  @override
  final String id;

  final Map<String, Object?>? _data;

  @override
  Map<String, Object?>? data() => _data;

  @override
  bool get exists => _data != null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
