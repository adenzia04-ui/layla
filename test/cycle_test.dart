import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/features/cycle/application/cycle_controller.dart';
import 'package:noor/features/cycle/domain/cycle.dart';
import 'package:noor/features/home/presentation/widgets/prayer_arc.dart';
import 'package:noor/features/home/presentation/widgets/prayer_grid.dart';
import 'package:noor/features/home/presentation/widgets/prayer_strip.dart';
import 'package:noor/features/onboarding/domain/journey_answers.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';
import 'package:noor/features/streaks/domain/streak_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The prayer pause: the arithmetic, not the screens.
///
/// A woman does not pray during menstruation, and those prayers are never made
/// up — there is no qada for them (Sahih Muslim 335). Everything below is a
/// consequence of that one fact. The day is not a day she failed at, so it may
/// not be recorded as missed, may not be asked for back, and may not cost her
/// a streak she has kept for months. Equally it is not a day she prayed, so it
/// may not hand her a streak she did not earn.
///
/// Those two together are the invariant, and it is the part most likely to be
/// got wrong, because getting it wrong in either direction looks reasonable
/// from inside a single function.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── Counting the days ───────────────────────────────────────────────────

  group('Cycle.dayCount', () {
    const Cycle cycle = Cycle(startedOn: '2026-09-15');

    test('the first day is Day 1, not Day 0', () {
      expect(
        cycle.dayCount(DateTime.utc(2026, 9, 15, 23, 59)),
        1,
        reason: 'it is shown to a person, and a person counts from one',
      );
    });

    test('the third day is Day 3', () {
      expect(cycle.dayCount(DateTime.utc(2026, 9, 17)), 3);
    });

    test('no pause counts no days', () {
      expect(Cycle.none.dayCount(DateTime.utc(2026, 9, 17)), 0);
      expect(Cycle.none.isActive, isFalse);
    });

    test('a malformed stored value is no pause at all', () {
      // The failure that matters here is the app inventing a pause nobody
      // asked for, so anything unreadable reads as none.
      expect(const Cycle(startedOn: 'whenever').isActive, isFalse);
      expect(
        Cycle.fromMap(const <String, Object?>{'startedOn': 7}).isActive,
        isFalse,
      );
      expect(Cycle.fromMap(null).isActive, isFalse);
    });

    test('a clock that went backwards still reads Day 1', () {
      // Travel across the date line, or a phone whose clock slipped. The pause
      // has begun either way, and "Day 0" or "Day -1" is not a thing to show
      // anybody.
      expect(cycle.dayCount(DateTime.utc(2026, 9, 14)), 1);
    });

    test('it survives a month boundary', () {
      expect(
        const Cycle(startedOn: '2026-08-30').dayCount(DateTime.utc(2026, 9, 2)),
        4,
      );
    });

    test('a long pause may be asked about, and only asked about', () {
      expect(cycle.isLongerThanUsual(DateTime.utc(2026, 9, 20)), isFalse);
      expect(cycle.isLongerThanUsual(DateTime.utc(2026, 9, 30)), isTrue);
      // Nothing here ends one. There is no `Cycle` method that can, and that
      // is deliberate: it ends when the bleeding stops and she has performed
      // ghusl, which the app cannot know.
    });

    test('nothing is asked before every school\'s maximum has passed', () {
      // The Hanafis hold ten days and the Shafi'is, Hanbalis and Malikis
      // fifteen. Asking on day eleven would tell a woman following any of the
      // latter three, by the mere fact of asking, that she was past what is
      // expected — the timing is the ruling, whatever the wording says.
      for (int day = 11; day <= 15; day++) {
        expect(
          cycle.isLongerThanUsual(
            DateTime.utc(2026, 9, 14).add(Duration(days: day)),
          ),
          isFalse,
          reason: 'day $day is inside three schools\' maximum',
        );
      }
    });

    test('the question is asked for a couple of days, not forever', () {
      // "May ask once" is the contract. Derived from the day count alone it
      // would sit on the home card every time she opened the app for as long
      // as the pause ran, which is pressure to end something only she can end.
      expect(cycle.dayCount(DateTime.utc(2026, 9, 30)), 16);
      expect(cycle.isLongerThanUsual(DateTime.utc(2026, 9, 30)), isTrue);
      expect(cycle.isLongerThanUsual(DateTime.utc(2026, 10, 1)), isTrue);
      expect(
        cycle.isLongerThanUsual(DateTime.utc(2026, 10, 2)),
        isFalse,
        reason: 'day 18 and onwards is nagging, not asking',
      );
      expect(cycle.isLongerThanUsual(DateTime.utc(2026, 11, 20)), isFalse);
    });

    test('the stored shape is the one key, or nothing', () {
      expect(cycle.toMap(), <String, Object?>{'startedOn': '2026-09-15'});
      expect(Cycle.none.toMap(), isNull);
      expect(Cycle.fromMap(cycle.toMap()), cycle);
    });
  });

  group('the days a pause covers', () {
    test('one definition, start day included', () {
      expect(
        CycleDays.covered('2026-09-15', DateTime.utc(2026, 9, 17)),
        <String>['2026-09-15', '2026-09-16', '2026-09-17'],
      );
    });

    test('no pause covers nothing', () {
      expect(CycleDays.covered(null, DateTime.utc(2026, 9, 17)), isEmpty);
    });

    test('a runaway pause is capped rather than back-filling a year', () {
      final List<String> days = CycleDays.covered(
        '2026-01-01',
        DateTime.utc(2026, 12, 31),
      );
      expect(days.length, Cycle.maxCoveredDays);
    });

    test('the cap keeps the newest days, and today above all', () {
      // Anchored at the start instead, the cap kept the *oldest* ninety days:
      // from day ninety-one today itself dropped out, nothing marked it,
      // `lastCompletedDate` stopped advancing, and two days later the streak
      // the pause exists to protect was gone with nothing on screen to say so.
      final DateTime today = DateTime.utc(2026, 6, 1);
      final List<String> days = CycleDays.covered('2026-01-01', today);

      expect(days.length, Cycle.maxCoveredDays);
      expect(days.last, Fmt.dayId(today));
      expect(
        days.contains(Fmt.dayId(today.subtract(const Duration(days: 1)))),
        isTrue,
      );
      // Still contiguous, so the chain is carried day by day to the present.
      for (int i = 1; i < days.length; i++) {
        expect(Fmt.dayIdBefore(days[i]), days[i - 1]);
      }
      expect(days.first, '2026-03-04');
    });

    test('days already recorded are not written again', () {
      expect(
        CycleDays.needingMark(
          startedOn: '2026-09-15',
          today: DateTime.utc(2026, 9, 17),
          alreadyExcused: <String>{'2026-09-15'},
          // She prayed all five on the 16th — the pause had not begun that
          // morning, or it ended and came back. Either way it is hers.
          alreadyComplete: <String>{'2026-09-16'},
        ),
        <String>['2026-09-17'],
      );
    });
  });

  // ── The invariant ───────────────────────────────────────────────────────

  group('the streak invariant', () {
    // Ten days prayed, six excused, one more prayed must read eleven. Not one
    // — the pause did not break the chain. Not seventeen — the pause did not
    // lengthen it either.
    final DateTime start = DateTime.utc(2026, 9, 1);

    /// Replays a run of days through the real arithmetic, in order.
    ///
    /// The same three methods the repository transactions call, so this cannot
    /// pass against an implementation the app does not use.
    ({StreakStats stats, DateTime lastDay}) replay(List<_Day> days) {
      StreakStats stats = const StreakStats();
      DateTime on = start;
      for (final _Day day in days) {
        final String id = Fmt.dayId(on);
        stats = switch (day) {
          _Day.prayed => stats.afterCompletedDay(id),
          _Day.excused => stats.afterExcusedDay(id),
          _Day.missed => stats.afterMissedDay(),
        };
        on = on.add(const Duration(days: 1));
      }
      return (stats: stats, lastDay: on.subtract(const Duration(days: 1)));
    }

    /// What the app would actually show on the last day of the run — the
    /// number on Home, not the number in the database. `UserStats.streakOn` is
    /// the thing that turns a stored count into a displayed one, and the whole
    /// mechanism depends on it, so the table asserts through it.
    int shown(({StreakStats stats, DateTime lastDay}) run) => UserStats(
      currentStreak: run.stats.currentStreak,
      lastCompletedDate: run.stats.lastCompletedDate,
    ).streakOn(run.lastDay);

    final List<({String name, List<_Day> days, int reads})> table =
        <({String name, List<_Day> days, int reads})>[
          (
            name: '10 prayed, 6 excused, 1 prayed reads 11',
            days: <_Day>[
              ..._n(_Day.prayed, 10),
              ..._n(_Day.excused, 6),
              _Day.prayed,
            ],
            reads: 11,
          ),
          (
            name: '10 prayed then 6 excused still reads 10 mid-pause',
            days: <_Day>[..._n(_Day.prayed, 10), ..._n(_Day.excused, 6)],
            reads: 10,
          ),
          (
            name: 'a single excused day does not raise a streak',
            days: <_Day>[_Day.excused],
            reads: 0,
          ),
          (
            name: 'a pause on a fresh account invents nothing',
            days: <_Day>[..._n(_Day.excused, 6)],
            reads: 0,
          ),
          (
            name: 'an excused day does not zero one',
            days: <_Day>[..._n(_Day.prayed, 3), _Day.excused],
            reads: 3,
          ),
          (
            name: 'a pause then a missed day still breaks it',
            days: <_Day>[
              ..._n(_Day.prayed, 10),
              ..._n(_Day.excused, 6),
              _Day.missed,
            ],
            reads: 0,
          ),
          (
            name: 'the day after the pause continues, it does not restart',
            days: <_Day>[
              ..._n(_Day.prayed, 4),
              ..._n(_Day.excused, 5),
              _Day.prayed,
              _Day.prayed,
            ],
            reads: 6,
          ),
          (
            name: 'a plain gap with no pause still breaks it',
            days: <_Day>[..._n(_Day.prayed, 10)],
            reads: 10,
          ),
        ];

    for (final ({String name, List<_Day> days, int reads}) row in table) {
      test(row.name, () {
        expect(shown(replay(row.days)), row.reads);
      });
    }

    test('a plain gap is what a missing record looks like', () {
      // The counterpart to the table: ten prayed days read as ten *on the last
      // of them*, and as nothing three days later. This is the failure the
      // pause has to avoid — a covered day left with no record at all is
      // indistinguishable from this.
      final ({StreakStats stats, DateTime lastDay}) run = replay(
        _n(_Day.prayed, 10),
      );
      expect(
        UserStats(
          currentStreak: run.stats.currentStreak,
          lastCompletedDate: run.stats.lastCompletedDate,
        ).streakOn(run.lastDay.add(const Duration(days: 3))),
        0,
      );
    });

    test('an excused day leaves the counter itself untouched', () {
      // The mechanism, stated directly: the date moves, the number does not.
      const StreakStats before = StreakStats(
        currentStreak: 10,
        longestStreak: 12,
        lastCompletedDate: '2026-09-10',
      );
      final StreakStats after = before.afterExcusedDay('2026-09-11');
      expect(after.currentStreak, 10);
      expect(after.longestStreak, 12);
      expect(after.lastCompletedDate, '2026-09-11');
    });

    test('a pause carries a live chain but never raises a dead one', () {
      // The direction nobody thought to test. `currentStreak` in Firestore is
      // never decayed — no Cloud Function runs on this project — so a lapse
      // nobody marked leaves a stale number that `streakOn` hides only because
      // the date is old. Moving the date forward un-hides it, and a woman who
      // had not prayed for a fortnight would open the app on the first day of
      // her pause and be handed back a ten-day streak she did not keep.
      const StreakStats lapsed = StreakStats(
        currentStreak: 10,
        longestStreak: 10,
        lastCompletedDate: '2026-09-01',
        lastConfirmedDate: '2026-09-01',
      );
      final StreakStats after = lapsed.afterExcusedDay('2026-09-15');

      expect(after.currentStreak, 0);
      expect(after.lastCompletedDate, '2026-09-15');
      expect(after.longestStreak, 10, reason: 'the record still happened');
      expect(
        UserStats(
          currentStreak: after.currentStreak,
          lastCompletedDate: after.lastCompletedDate,
        ).streakOn(DateTime.utc(2026, 9, 15)),
        0,
      );
      // And it restarts at one on the next day she finishes, like anybody
      // else's would.
      expect(after.afterCompletedDay('2026-09-16').currentStreak, 1);
    });

    test('consecutive excused days keep carrying a chain that is alive', () {
      StreakStats stats = const StreakStats(
        currentStreak: 10,
        longestStreak: 10,
        lastCompletedDate: '2026-09-10',
        lastConfirmedDate: '2026-09-10',
      );
      for (int i = 11; i <= 16; i++) {
        stats = stats.afterExcusedDay('2026-09-$i');
        expect(stats.currentStreak, 10, reason: 'day $i');
      }
      expect(stats.afterCompletedDay('2026-09-17').currentStreak, 11);
    });

    test('the confirmed date stays where the last real completion left it', () {
      // The half of the date that may leave the phone. A pause must not move
      // it, or the scoreboard would carry the same fact the carried date does.
      StreakStats stats = const StreakStats(
        currentStreak: 10,
        longestStreak: 10,
        lastCompletedDate: '2026-09-10',
        lastConfirmedDate: '2026-09-10',
      );
      for (int i = 11; i <= 16; i++) {
        stats = stats.afterExcusedDay('2026-09-$i');
      }
      expect(stats.lastCompletedDate, '2026-09-16');
      expect(stats.lastConfirmedDate, '2026-09-10');
      expect(
        stats.afterCompletedDay('2026-09-17').lastConfirmedDate,
        '2026-09-17',
      );
    });

    test('an account from before the split still publishes a real date', () {
      // The migration, and why it tests the key rather than the value. Before
      // the pause existed the two dates were one fact, so an account that
      // predates the field carries its last real completion in
      // `lastCompletedDate` and its friends' cards keep reading right through
      // the upgrade.
      final StreakStats old = StreakStats.fromMap(const <String, Object?>{
        'currentStreak': 9,
        'lastCompletedDate': '2026-09-10',
      });
      expect(old.lastConfirmedDate, '2026-09-10');

      // And once anything has written the key — the pause writes it null
      // included, precisely for this — the fallback is retired, or it would
      // hand the scoreboard the excused date it exists to keep off it.
      final StreakStats paused = StreakStats.fromMap(const <String, Object?>{
        'currentStreak': 0,
        'lastCompletedDate': '2026-09-15',
        'lastConfirmedDate': null,
      });
      expect(paused.lastConfirmedDate, isNull);
      expect(paused.lastCompletedDate, '2026-09-15');

      final StreakStats normal = StreakStats.fromMap(const <String, Object?>{
        'lastCompletedDate': '2026-09-15',
        'lastConfirmedDate': '2026-09-12',
      });
      expect(normal.lastConfirmedDate, '2026-09-12');
    });

    test('an excused day never drags the chain backwards', () {
      // A back-fill of an older day arriving after a newer one — which is also
      // what makes running the catch-up twice cost nothing.
      const StreakStats stats = StreakStats(
        currentStreak: 6,
        lastCompletedDate: '2026-09-14',
      );
      expect(stats.afterExcusedDay('2026-09-12'), stats);
      expect(stats.afterExcusedDay('2026-09-14'), stats);
    });

    test('a completed day counted twice is still one day', () {
      const StreakStats stats = StreakStats(
        currentStreak: 4,
        lastCompletedDate: '2026-09-14',
      );
      expect(stats.afterCompletedDay('2026-09-14').currentStreak, 4);
    });

    test('longest is a record of what happened and survives a break', () {
      final ({StreakStats stats, DateTime lastDay}) run = replay(<_Day>[
        ..._n(_Day.prayed, 7),
        _Day.missed,
      ]);
      expect(run.stats.currentStreak, 0);
      expect(run.stats.longestStreak, 7);
    });
  });

  // ── The catch-up ────────────────────────────────────────────────────────

  group('the catch-up', () {
    /// One pass of `CycleRepository.catchUp`, with the Firestore taken out.
    ///
    /// The loop is the repository's: work out which covered days still need
    /// marking, then put each through the same decision
    /// `PrayerDayRepository.markExcused` makes inside its transaction. What is
    /// being checked is that a second pass finds nothing to do — the app opens
    /// this code on every launch.
    ({StreakStats stats, Set<String> excused, int writes}) pass({
      required String startedOn,
      required DateTime today,
      required StreakStats stats,
      required Set<String> excused,
      Set<String> complete = const <String>{},
    }) {
      final Set<String> marked = <String>{...excused};
      StreakStats current = stats;
      int writes = 0;

      for (final String dateId in CycleDays.needingMark(
        startedOn: startedOn,
        today: today,
        alreadyExcused: marked,
        alreadyComplete: complete,
      )) {
        final ExcusedDayWrite write = ExcusedDayWrite.decide(
          dateId: dateId,
          dayIsComplete: complete.contains(dateId),
          dayIsExcused: marked.contains(dateId),
          stats: current,
        );
        if (write.isEmpty) continue;
        writes++;
        if (write.marksDay) marked.add(dateId);
        if (write.stats != null) current = write.stats!;
      }
      return (stats: current, excused: marked, writes: writes);
    }

    test(
      'running it twice writes the same state and does not move anything',
      () {
        const StreakStats earned = StreakStats(
          currentStreak: 10,
          longestStreak: 10,
          lastCompletedDate: '2026-09-14',
        );

        final ({StreakStats stats, Set<String> excused, int writes}) first =
            pass(
              startedOn: '2026-09-15',
              today: DateTime.utc(2026, 9, 17),
              stats: earned,
              excused: <String>{},
            );
        expect(first.writes, 3, reason: 'three days nobody was open to record');
        expect(first.excused, <String>{
          '2026-09-15',
          '2026-09-16',
          '2026-09-17',
        });
        expect(first.stats.lastCompletedDate, '2026-09-17');
        expect(first.stats.currentStreak, 10);

        final ({StreakStats stats, Set<String> excused, int writes}) second =
            pass(
              startedOn: '2026-09-15',
              today: DateTime.utc(2026, 9, 17),
              stats: first.stats,
              excused: first.excused,
            );
        expect(
          second.writes,
          0,
          reason: 'ten app opens in a day cost no writes',
        );
        expect(second.stats, first.stats);
        expect(second.excused, first.excused);
      },
    );

    test('a day she prayed in full is left completely alone', () {
      // Overwriting it would erase a day she actually prayed and replace it
      // with one she did not owe.
      final ({StreakStats stats, Set<String> excused, int writes}) run = pass(
        startedOn: '2026-09-15',
        today: DateTime.utc(2026, 9, 16),
        stats: const StreakStats(
          currentStreak: 3,
          lastCompletedDate: '2026-09-16',
        ),
        excused: <String>{},
        complete: <String>{'2026-09-16'},
      );
      expect(run.excused, <String>{'2026-09-15'});
      expect(run.stats.lastCompletedDate, '2026-09-16');
      expect(run.stats.currentStreak, 3);
    });

    test('a day already excused needs nothing', () {
      expect(
        ExcusedDayWrite.decide(
          dateId: '2026-09-15',
          dayIsComplete: false,
          dayIsExcused: true,
          stats: const StreakStats(lastCompletedDate: '2026-09-15'),
        ).isEmpty,
        isTrue,
      );
    });

    test('a completed day is never touched, whatever the stats say', () {
      expect(
        ExcusedDayWrite.decide(
          dateId: '2026-09-15',
          dayIsComplete: true,
          dayIsExcused: false,
          stats: const StreakStats(),
        ).isEmpty,
        isTrue,
      );
    });

    test('a day excused but not yet carried still carries the chain', () {
      // The half-written case: the day document landed and the stats write did
      // not. The next open finishes the job rather than shrugging.
      final ExcusedDayWrite write = ExcusedDayWrite.decide(
        dateId: '2026-09-15',
        dayIsComplete: false,
        dayIsExcused: true,
        stats: const StreakStats(
          currentStreak: 10,
          lastCompletedDate: '2026-09-14',
        ),
      );
      expect(write.marksDay, isFalse);
      expect(write.stats?.lastCompletedDate, '2026-09-15');
      expect(write.stats?.currentStreak, 10);
    });
  });

  // ── Who it is for ───────────────────────────────────────────────────────

  group('isSisterProvider', () {
    /// The provider as the app wires it: the profile, with the onboarding
    /// answer still on the phone behind it.
    Future<bool> ask({String? profileGender, String? deviceGender}) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        if (deviceGender != null)
          'journey_answers': JourneyAnswers(gender: deviceGender).encode(),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          prefsProvider.overrideWithValue(PrefsService(prefs)),
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              AppUser(
                uid: 'u1',
                displayName: 'Maryam',
                email: 'maryam@example.com',
                gender: profileGender,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appUserProvider.future);
      return container.read(isSisterProvider);
    }

    test('true for a sister', () async {
      expect(await ask(profileGender: Gender.sister), isTrue);
    });

    test('false for a brother', () async {
      expect(await ask(profileGender: Gender.brother), isFalse);
    });

    test('false when nobody answered', () async {
      expect(await ask(), isFalse);
    });

    test(
      'the onboarding answer carries anyone who signed up before this',
      () async {
        // Their profile has no gender because nothing wrote one; the answer is
        // still on the phone. Without this fallback the feature would appear for
        // nobody already using the app, with nothing on screen to explain why.
        expect(await ask(deviceGender: Gender.sister), isTrue);
      },
    );

    test('the profile wins over a stale answer on the phone', () async {
      // Two people, one phone. The account is the authority once it has one.
      expect(
        await ask(profileGender: Gender.brother, deviceGender: Gender.sister),
        isFalse,
      );
      expect(
        await ask(profileGender: Gender.sister, deviceGender: Gender.brother),
        isTrue,
      );
    });

    test('an unrecognised stored value is not a sister', () async {
      expect(await ask(profileGender: 'other', deviceGender: 'other'), isFalse);
    });
  });

  // ── An excused day is not a missed one ──────────────────────────────────

  group('PrayerStatus.excused', () {
    final PrayerDay excusedDay = PrayerDay(
      dateId: '2026-09-15',
      excused: true,
      records: <PrayerId, PrayerRecord>{
        for (final PrayerId id in PrayerId.obligatory)
          id: const PrayerRecord(status: PrayerStatus.excused),
      },
    );

    test('it survives the round trip to Firestore and back', () {
      expect(PrayerStatus.fromKey('excused'), PrayerStatus.excused);
      expect(PrayerStatus.excused.key, 'excused');
      // Anything unreadable falls back to pending, never to excused: the app
      // must not invent a pause from a malformed record.
      expect(PrayerStatus.fromKey('nonsense'), PrayerStatus.pending);
      expect(PrayerStatus.fromKey(null), PrayerStatus.pending);
    });

    test('it settles a prayer without counting it', () {
      expect(PrayerStatus.excused.isSettled, isTrue);
      expect(
        PrayerStatus.excused.countsForStreak,
        isFalse,
        reason: 'only a confirmed prayer counts',
      );
      expect(PrayerStatus.pending.isSettled, isFalse);
      expect(PrayerStatus.awaitingProof.isSettled, isFalse);
    });

    test('an excused day has missed nothing', () {
      expect(
        excusedDay.anyMissed,
        isFalse,
        reason: 'none of these prayers was owed',
      );
    });

    test('an excused day is not a complete one either', () {
      expect(excusedDay.isComplete, isFalse);
      expect(excusedDay.completedCount, 0);
    });

    test('a prayer confirmed on an excused day still counts, and the day '
        'still does not', () {
      // She may pray the moment the pause ends, and that prayer is recorded.
      // The day has already carried the chain once, so it must not complete
      // and carry it again.
      final PrayerDay mixed = PrayerDay(
        dateId: '2026-09-15',
        excused: true,
        records: <PrayerId, PrayerRecord>{
          for (final PrayerId id in PrayerId.obligatory)
            id: const PrayerRecord(status: PrayerStatus.completed),
        },
      );
      expect(mixed.completedCount, PrayerId.obligatory.length);
      expect(
        mixed.isComplete,
        isFalse,
        reason: 'this is what stops a pause inflating a streak',
      );
    });

    test('an excused day is not a perfect day in the year view', () {
      final StreakHistory year = StreakHistory(
        year: 2026,
        days: <String, PrayerDay>{'2026-09-15': excusedDay},
      );
      expect(year.perfectDays, 0);
      expect(year.totalConfirmed, 0);
    });

    test('nothing on it is awaiting a photo', () {
      expect(excusedDay.awaitingProof, isNull);
    });

    test('the year bar counts what was owed, not five times every day', () {
      // The one place in the app that puts a number on it. An excused day adds
      // nothing to `totalConfirmed`, so counting it in full in the denominator
      // holds a woman who prayed everything she owed permanently short of
      // 100% — roughly 84% for a typical cycle, for every year she uses the
      // app, beside a brother's 100%. These prayers are not made up (Sahih
      // Muslim 335) and nothing may present them as a shortfall.
      final int all = PrayerId.obligatory.length;
      final StreakHistory year = StreakHistory(
        year: 2026,
        days: <String, PrayerDay>{
          for (int d = 1; d <= 6; d++)
            '2026-09-0$d': PrayerDay(
              dateId: '2026-09-0$d',
              records: <PrayerId, PrayerRecord>{
                for (final PrayerId id in PrayerId.obligatory)
                  id: const PrayerRecord(status: PrayerStatus.completed),
              },
            ),
          for (int d = 7; d <= 9; d++) '2026-09-0$d': excusedDay,
        },
      );

      expect(year.totalConfirmed, 6 * all);
      expect(
        year.owedPrayers(9),
        6 * all,
        reason: 'three paused days owed nothing at all',
      );
      expect(year.totalConfirmed / year.owedPrayers(9), 1.0);
    });

    test(
      'a day the pause began part-way through owes only what she prayed',
      () {
        // The worst version: Fajr prayed that morning, the pause from Dhuhr.
        // `markExcused` rightly leaves the Fajr confirmed, so counting the day
        // at five would charge her four prayers she was never asked to pray.
        final PrayerDay partial = PrayerDay(
          dateId: '2026-09-15',
          excused: true,
          records: <PrayerId, PrayerRecord>{
            PrayerId.fajr: const PrayerRecord(status: PrayerStatus.completed),
            for (final PrayerId id in PrayerId.obligatory.skip(1))
              id: const PrayerRecord(status: PrayerStatus.excused),
          },
        );
        final StreakHistory year = StreakHistory(
          year: 2026,
          days: <String, PrayerDay>{'2026-09-15': partial},
        );

        expect(year.totalConfirmed, 1);
        expect(year.owedPrayers(1), 1);
      },
    );

    test('an ordinary year is still five a day', () {
      const StreakHistory year = StreakHistory(
        year: 2026,
        days: <String, PrayerDay>{},
      );
      expect(year.owedPrayers(100), 100 * PrayerId.obligatory.length);
      expect(year.owedPrayers(0), 0);
    });
  });

  // ── What she is shown ───────────────────────────────────────────────────

  /// The projection Home draws from while the catch-up write is still in the
  /// air.
  ///
  /// Its whole job is to show the answer that write is about to bring back, so
  /// what matters is that it agrees with `PrayerDayRepository.markExcused`
  /// field for field. If it does not, the screen changes under her a second
  /// after it settles — which is worse than the gap it was added to close.
  group('PrayerDay.asExcused', () {
    test('marks the day and all five prayers', () {
      final PrayerDay projected = const PrayerDay(
        dateId: '2026-09-15',
      ).asExcused();

      expect(projected.excused, isTrue);
      for (final PrayerId id in PrayerId.obligatory) {
        expect(projected.recordFor(id).status, PrayerStatus.excused);
      }
    });

    test('leaves a prayer confirmed before the pause began alone', () {
      // She prayed Fajr, and the pause began later that morning. The
      // repository writes excused only over what was not confirmed, and this
      // has to do the same — erasing a prayer she actually prayed would be a
      // worse error than the one this whole projection exists to prevent.
      final PrayerDay projected = const PrayerDay(
        dateId: '2026-09-15',
        records: <PrayerId, PrayerRecord>{
          PrayerId.fajr: PrayerRecord(status: PrayerStatus.completed),
        },
      ).asExcused();

      expect(projected.recordFor(PrayerId.fajr).status, PrayerStatus.completed);
      expect(projected.completedCount, 1);
      expect(projected.recordFor(PrayerId.dhuhr).status, PrayerStatus.excused);
    });

    test('is never complete and never shows as missed', () {
      // The two things a paused day must not become. `isComplete` would
      // advance the chain a second time for one day; `anyMissed` would paint
      // it red in the year view.
      final PrayerDay projected = const PrayerDay(
        dateId: '2026-09-15',
        records: <PrayerId, PrayerRecord>{
          PrayerId.fajr: PrayerRecord(status: PrayerStatus.missed),
        },
      ).asExcused();

      expect(projected.isComplete, isFalse);
      expect(projected.anyMissed, isFalse);
    });

    test('carries Tahajjud across untouched', () {
      // Tahajjud is not one of the five and is not owed by anybody, so a pause
      // has no opinion about it either way.
      final PrayerDay projected = PrayerDay(
        dateId: '2026-09-15',
        tahajjudPrayed: true,
        tahajjudAt: DateTime(2026, 9, 15, 3, 20),
      ).asExcused();

      expect(projected.tahajjudPrayed, isTrue);
      expect(projected.tahajjudAt, DateTime(2026, 9, 15, 3, 20));
    });

    test('a day she finished before it began is handed back untouched', () {
      // `markExcused` leaves a finished day completely alone — there is
      // nothing on it to excuse and the completion carried the chain itself —
      // and this has to match, or Home would blank the count on a day she
      // actually finished. The evening a pause begins is the common case.
      final PrayerDay finished = PrayerDay(
        dateId: '2026-09-15',
        records: <PrayerId, PrayerRecord>{
          for (final PrayerId id in PrayerId.obligatory)
            id: const PrayerRecord(status: PrayerStatus.completed),
        },
      );

      expect(finished.asExcused(), same(finished));
      expect(finished.asExcused().excused, isFalse);
      expect(finished.asExcused().isComplete, isTrue);
      expect(finished.asExcused().completedCount, 5);
    });

    test('changes nothing on a day the catch-up has already written', () {
      // The write landing must be a no-op on screen, which is the same thing
      // as saying the projection predicted it.
      final PrayerDay written = PrayerDay(
        dateId: '2026-09-15',
        excused: true,
        records: <PrayerId, PrayerRecord>{
          for (final PrayerId id in PrayerId.obligatory)
            id: const PrayerRecord(status: PrayerStatus.excused),
        },
      );
      final PrayerDay projected = written.asExcused();

      expect(projected.excused, written.excused);
      expect(projected.completedCount, written.completedCount);
      for (final PrayerId id in PrayerId.obligatory) {
        expect(projected.recordFor(id).status, written.recordFor(id).status);
      }
    });
  });

  group('an excused prayer is never drawn as a missed one', () {
    // The status switches that decide colour. Rose is the app's colour for
    // missed, and a paused prayer wearing it would be the app telling a woman
    // she is behind on prayers she does not owe and cannot make up.
    final DateTime date = DateTime(2026, 9, 15);
    DateTime at(int h, int m) => DateTime(2026, 9, 15, h, m);

    final PrayerSchedule schedule = PrayerSchedule(
      date: date,
      slots: <PrayerSlot>[
        PrayerSlot(id: PrayerId.fajr, start: at(5, 52), end: at(7, 11)),
        PrayerSlot(id: PrayerId.sunrise, start: at(7, 11), end: at(13, 17)),
        PrayerSlot(id: PrayerId.dhuhr, start: at(13, 17), end: at(16, 32)),
        PrayerSlot(id: PrayerId.asr, start: at(16, 32), end: at(19, 23)),
        PrayerSlot(id: PrayerId.maghrib, start: at(19, 23), end: at(20, 33)),
        PrayerSlot(id: PrayerId.isha, start: at(20, 33), end: at(23, 59)),
      ],
      tahajjud: TahajjudWindow(start: at(2, 0), end: at(5, 52)),
      qiblaBearing: 292,
      latitude: 3.139,
      longitude: 101.6869,
    );

    final PrayerDay excusedDay = PrayerDay(
      dateId: '2026-09-15',
      excused: true,
      records: <PrayerId, PrayerRecord>{
        for (final PrayerId id in PrayerId.obligatory)
          id: const PrayerRecord(status: PrayerStatus.excused),
      },
    );

    const PrayerDay missedDay = PrayerDay(
      dateId: '2026-09-15',
      records: <PrayerId, PrayerRecord>{
        PrayerId.fajr: PrayerRecord(status: PrayerStatus.missed),
      },
    );

    Iterable<Color?> iconColours(WidgetTester tester) => tester
        .widgetList<Icon>(find.byType(Icon))
        .map((Icon icon) => icon.color);

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(393 * 3, 700 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.midnight,
            body: Padding(padding: const EdgeInsets.all(20), child: child),
          ),
        ),
      );
    }

    testWidgets('the grid marks it neutrally', (WidgetTester tester) async {
      await pump(
        tester,
        PrayerGrid(schedule: schedule, now: at(21, 0), day: excusedDay),
      );
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
      expect(
        find.byWidgetPredicate(
          (Widget w) =>
              w is Icon &&
              w.icon == Icons.remove_rounded &&
              w.color == AppColors.mistFaint,
        ),
        findsWidgets,
      );
    });

    testWidgets('though it still marks a real miss', (
      WidgetTester tester,
    ) async {
      // The counterpart, so the test above cannot pass by the grid having
      // stopped drawing anything at all.
      await pump(
        tester,
        PrayerGrid(schedule: schedule, now: at(21, 0), day: missedDay),
      );
      expect(iconColours(tester), contains(AppColors.rose));
    });

    testWidgets('and so does the strip', (WidgetTester tester) async {
      await pump(
        tester,
        PrayerStrip(schedule: schedule, now: at(21, 0), day: excusedDay),
      );
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
    });

    testWidgets('and so does the arc on Home', (WidgetTester tester) async {
      // The third surface, and the one sitting directly above the panel that
      // says nothing is missed. Home hands it the same day it hands the
      // progress card — see `cycleDayFor` — so what it must not do is put a
      // cross against a prayer the pause covers.
      await pump(
        tester,
        PrayerArc(schedule: schedule, now: at(21, 0), day: excusedDay),
      );
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
    });

    testWidgets('though the arc still marks a real miss', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        PrayerArc(schedule: schedule, now: at(21, 0), day: missedDay),
      );
      expect(iconColours(tester), contains(AppColors.rose));
    });
  });
}

/// How one day of a run went, for the invariant table.
enum _Day { prayed, excused, missed }

List<_Day> _n(_Day day, int count) => List<_Day>.filled(count, day);
