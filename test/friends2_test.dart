import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/features/circles/domain/circle.dart';
import 'package:noor/features/friends/application/friends_controller.dart';
import 'package:noor/features/friends/application/invite.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/friends/domain/inbox_item.dart';
import 'package:noor/features/friends/domain/jumuah.dart';
import 'package:noor/features/friends/domain/ramadan.dart';
import 'package:noor/features/prayer_times/application/prayer_times_controller.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/application/streak_controller.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';

/// Friends, round two: what leaves the phone, with no Firestore anywhere near.
///
/// Every feature here ends in a document somebody else reads, so the tests
/// are about the two moments that matter: what this phone writes — zeros when
/// quiet, a milestone once and never again, one integer per circle — and
/// what a friend's phone makes of the fields it was handed. The arithmetic
/// behind "prayers together" and the Hijri calendar behind Eid are pinned
/// here too, because both are the kind of thing that looks right on the day
/// it is written and wrong on a day nobody is watching.
void main() {
  final DateTime today = DateTime(2026, 9, 14);
  final String todayId = Fmt.dayId(today);

  FriendProgress progress({
    bool quiet = false,
    Milestone? milestone,
    RamadanShare? ramadan,
  }) => FriendProgress(
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
    quiet: quiet,
    milestone: milestone,
    ramadan: ramadan,
  );

  final Milestone milestone = Milestone(
    key: MilestoneKey.prayers1000,
    at: DateTime(2026, 9, 10, 21, 30),
  );
  const RamadanShare share = RamadanShare(
    fasts: 12,
    fastingToday: true,
    taraweeh: false,
    date: '2026-09-14',
  );

  /// The document as Firestore would hold it: the map the publisher writes,
  /// plus the server stamp `toMap` deliberately leaves out.
  FriendProgress roundTrip(FriendProgress sent) => FriendProgress.fromDoc(
    _FakeDoc('them', <String, Object?>{
      ...sent.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 14, 21, 30)),
    }),
  );

  group('FriendProgress round trip', () {
    test('with none of the new keys', () {
      final FriendProgress back = roundTrip(progress());
      expect(back.quiet, isFalse);
      expect(back.milestone, isNull);
      expect(back.ramadan, isNull);
      expect(back.totalPrayers, 1240, reason: 'the old fields still travel');
      expect(progress().toMap().containsKey('milestone'), isFalse);
      expect(progress().toMap().containsKey('ramadan'), isFalse);
      expect(
        progress().toMap()['quiet'],
        isFalse,
        reason: 'quiet is always written, so a friend reads an explicit false',
      );
    });

    test('with a milestone', () {
      final FriendProgress back = roundTrip(progress(milestone: milestone));
      expect(back.milestone, milestone);
      expect(back.milestone!.key.label, '1,000 prayers');
      expect(back.ramadan, isNull);
    });

    test('with a Ramadan line', () {
      final FriendProgress back = roundTrip(progress(ramadan: share));
      expect(back.ramadan, share);
      expect(back.milestone, isNull);
    });

    test('with quiet', () {
      final FriendProgress back = roundTrip(progress(quiet: true));
      expect(back.quiet, isTrue);
    });

    test('with all three', () {
      final FriendProgress back = roundTrip(
        progress(quiet: true, milestone: milestone, ramadan: share),
      );
      expect(back.quiet, isTrue);
      expect(back.milestone, milestone);
      expect(back.ramadan, share);
    });

    test('a document from an older build has none of them', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{'code': 'DEF345', 'streak': 3}),
      );
      expect(back.quiet, isFalse);
      expect(back.milestone, isNull);
      expect(back.ramadan, isNull);
    });

    test('malformed keys read as absent rather than throwing', () {
      // Somebody else's document. A cast that threw would take the friend's
      // whole card down; a shape this app never wrote simply is not there.
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          'quiet': 'yes',
          'milestone': 'streak100',
          'ramadan': 42,
        }),
      );
      expect(back.quiet, isFalse);
      expect(back.milestone, isNull);
      expect(back.ramadan, isNull);

      final FriendProgress unknown = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          'milestone': <String, Object?>{
            'key': 'streak1000000',
            'at': Timestamp.fromDate(today),
          },
          'ramadan': <String, Object?>{'fasts': 99, 'date': 'soon'},
        }),
      );
      expect(unknown.milestone, isNull, reason: 'a key from a newer build');
      expect(unknown.ramadan, isNull, reason: 'a date that is not a day id');
    });

    test('a milestone the server has not stamped yet is not one yet', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          'milestone': <String, Object?>{'key': 'streak100', 'at': null},
        }),
      );
      expect(back.milestone, isNull);
    });

    test('a Ramadan count past thirty is cut, not trusted', () {
      final RamadanShare? back = RamadanShare.fromMap(<String, Object?>{
        'fasts': 99,
        'fastingToday': true,
        'taraweeh': 'yes',
        'date': '2027-02-20',
      });
      expect(back!.fasts, RamadanShare.maxFasts);
      expect(back.taraweeh, isFalse, reason: 'tested, not cast');
    });
  });

  group('Milestone.isFresh', () {
    final DateTime at = DateTime(2026, 9, 1, 12);
    final Milestone m = Milestone(key: MilestoneKey.streak100, at: at);

    test('six days on it is still shown', () {
      expect(m.isFreshOn(at.add(const Duration(days: 6))), isTrue);
    });

    test('eight days on it is gone', () {
      expect(m.isFreshOn(at.add(const Duration(days: 8))), isFalse);
    });

    test('exactly a week is the edge, and the edge is off', () {
      expect(m.isFreshOn(at.add(const Duration(days: 7))), isFalse);
      expect(m.isFreshOn(at.add(const Duration(days: 7, seconds: -1))), isTrue);
    });

    test('a milestone slightly in the future is fresh, not broken', () {
      // A phone clock a little behind the server's must not hide a milestone
      // the server stamped a minute ago.
      expect(m.isFreshOn(at.subtract(const Duration(minutes: 5))), isTrue);
    });
  });

  // The decision the sync makes, in the open. `crossedBy` reads the counters
  // and `next` compares them with what the profile already records; the
  // provider below runs the same two through real stats.
  group('milestone thresholds', () {
    Set<MilestoneKey> crossed({
      int streak = 0,
      int prayers = 0,
      int tahajjud = 0,
    }) => MilestoneKey.crossedBy(
      streak: streak,
      totalPrayers: prayers,
      totalTahajjud: tahajjud,
    );

    MilestoneKey? next(
      Set<MilestoneKey> crossed, {
      Milestone? current,
      Set<MilestoneKey> reached = const <MilestoneKey>{},
    }) => Milestone.next(crossed: crossed, current: current, reached: reached);

    Milestone recorded(MilestoneKey key) =>
        Milestone(key: key, at: DateTime(2026, 8, 1));

    test('99 days is nothing', () {
      expect(crossed(streak: 99), isEmpty);
      expect(next(crossed(streak: 99)), isNull);
    });

    test('100 days is streak100', () {
      expect(next(crossed(streak: 100)), MilestoneKey.streak100);
    });

    test('365 days is streak365', () {
      // Both are crossed; the rarer one goes on the card and the smaller is
      // recorded as reached alongside it, never celebrated late.
      expect(crossed(streak: 365), <MilestoneKey>{
        MilestoneKey.streak100,
        MilestoneKey.streak365,
      });
      expect(next(crossed(streak: 365)), MilestoneKey.streak365);
    });

    test('a stat that regresses does not downgrade', () {
      // The chain broke after a year and climbed back to a hundred. A
      // hundred was passed on the way to 365, and the document says so
      // whether or not the reached list was ever written.
      expect(
        next(crossed(streak: 100), current: recorded(MilestoneKey.streak365)),
        isNull,
      );
      expect(
        next(
          crossed(streak: 100),
          current: recorded(MilestoneKey.streak365),
          reached: <MilestoneKey>{
            MilestoneKey.streak100,
            MilestoneKey.streak365,
          },
        ),
        isNull,
      );
    });

    test('the same key is not rewritten', () {
      // Every launch runs this. A rewrite would move `at`, keep the badge
      // fresh for ever and count every friend's cheer again.
      expect(
        next(crossed(streak: 100), current: recorded(MilestoneKey.streak100)),
        isNull,
      );
      expect(
        next(crossed(streak: 140), current: recorded(MilestoneKey.streak100)),
        isNull,
        reason: 'a hundred and forty is still the hundred-day milestone',
      );
    });

    test('a milestone on another counter is not recorded twice', () {
      // First Tahajjud went on the card last year and was replaced by the
      // hundred days. Without the reached list the two would take turns.
      expect(
        next(
          crossed(streak: 120, tahajjud: 5),
          current: recorded(MilestoneKey.streak100),
          reached: <MilestoneKey>{MilestoneKey.tahajjud1},
        ),
        isNull,
      );
      expect(
        next(
          crossed(streak: 120, tahajjud: 100),
          current: recorded(MilestoneKey.streak100),
          reached: <MilestoneKey>{MilestoneKey.tahajjud1},
        ),
        MilestoneKey.tahajjud100,
        reason: 'but a genuinely new one on that counter still is',
      );
    });

    test('the other four thresholds', () {
      expect(next(crossed(prayers: 999)), isNull);
      expect(next(crossed(prayers: 1000)), MilestoneKey.prayers1000);
      expect(next(crossed(prayers: 5000)), MilestoneKey.prayers5000);
      expect(next(crossed(tahajjud: 1)), MilestoneKey.tahajjud1);
      expect(next(crossed(tahajjud: 100)), MilestoneKey.tahajjud100);
    });

    test('several at once puts the rarest on the card', () {
      // The first launch after this shipped, for an account with years
      // behind it. One badge, and it is the one worth a MashaAllah.
      expect(
        next(crossed(streak: 400, prayers: 6000, tahajjud: 200)),
        MilestoneKey.prayers5000,
      );
    });

    test('the stored key is the enum name, one of exactly six', () {
      for (final MilestoneKey key in MilestoneKey.values) {
        expect(MilestoneKey.fromKey(key.key), key);
      }
      expect(MilestoneKey.fromKey('streak1000'), isNull);
      expect(MilestoneKey.values.map((MilestoneKey k) => k.key), <String>[
        'streak100',
        'streak365',
        'prayers1000',
        'prayers5000',
        'tahajjud1',
        'tahajjud100',
      ]);
    });
  });

  group('milestoneDueProvider', () {
    Future<MilestoneKey?> due(
      UserStats stats, {
      Milestone? current,
      Set<MilestoneKey> reached = const <MilestoneKey>{},
    }) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          friendsUidProvider.overrideWithValue('me'),
          todayProvider.overrideWithValue(today),
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              AppUser(
                uid: 'me',
                displayName: 'Amira Khan',
                email: 'amira@example.com',
                stats: stats,
                milestone: current,
                milestonesReached: reached,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appUserProvider.future);
      return container.read(milestoneDueProvider);
    }

    test('reads the calendar-checked streak, not the stored counter', () async {
      // The stored counter is never decayed on this plan. A chain that
      // lapsed ten days ago still says a hundred, and a hundred it did not
      // keep must not become a badge.
      expect(
        await due(
          const UserStats(currentStreak: 100, lastCompletedDate: '2026-09-13'),
        ),
        MilestoneKey.streak100,
      );
      expect(
        await due(
          const UserStats(currentStreak: 100, lastCompletedDate: '2026-09-04'),
        ),
        isNull,
      );
    });

    test('is idempotent across launches', () async {
      const UserStats stats = UserStats(
        currentStreak: 100,
        lastCompletedDate: '2026-09-13',
      );
      expect(
        await due(
          stats,
          current: Milestone(key: MilestoneKey.streak100, at: today),
        ),
        isNull,
      );
      expect(
        await due(stats, reached: <MilestoneKey>{MilestoneKey.streak100}),
        isNull,
        reason: 'the reached list alone is enough, while the stamp is pending',
      );
    });

    test('a guest crosses nothing', () async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[friendsUidProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      expect(container.read(milestoneDueProvider), isNull);
    });
  });

  // What this phone publishes, built by the real provider. The quiet document
  // is the server-side half of "go quiet": every number a zero, and neither
  // optional map present, so there is nothing in Firestore for any client to
  // show — hiding them on the reading side alone would not be quiet.
  group('the quiet publish', () {
    final RamadanRecord fasting = RamadanRecord(
      year: HijriDates.yearOf(today),
      fasts: 12,
      fastedOn: todayId,
      taraweehOn: todayId,
    );

    Future<FriendProgress?> published({
      required bool quiet,
      bool ramadan = true,
    }) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          friendsUidProvider.overrideWithValue('me'),
          myFriendCodeProvider.overrideWith((Ref ref) async => 'ABC234'),
          isRamadanProvider.overrideWithValue(ramadan),
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              AppUser(
                uid: 'me',
                displayName: 'Amira Khan',
                email: 'amira@example.com',
                photoThumb: 'B' * 6000,
                quiet: quiet,
                milestone: milestone,
                ramadan: fasting,
                stats: const UserStats(
                  currentStreak: 12,
                  longestStreak: 30,
                  totalPrayers: 1240,
                  totalTahajjud: 312,
                  lastCompletedDate: '2026-09-13',
                  lastConfirmedDate: '2026-09-13',
                ),
              ),
            ),
          ),
          todayProvider.overrideWithValue(today),
          todayPrayerDayProvider.overrideWith(
            (Ref ref) => Stream<PrayerDay>.value(
              PrayerDay(
                dateId: todayId,
                records: <PrayerId, PrayerRecord>{
                  for (final PrayerId id in PrayerId.obligatory.take(3))
                    id: const PrayerRecord(status: PrayerStatus.completed),
                },
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(myFriendCodeProvider.future);
      await container.read(appUserProvider.future);
      await container.read(todayPrayerDayProvider.future);
      return container.read(myProgressProvider);
    }

    test('is all zeros, with no milestone and no Ramadan line', () async {
      final FriendProgress? p = await published(quiet: true);
      final Map<String, Object?> doc = p!.toMap();

      expect(doc['quiet'], isTrue);
      expect(doc['streak'], 0);
      expect(doc['longestStreak'], 0);
      expect(doc['totalPrayers'], 0);
      expect(doc['totalTahajjud'], 0);
      expect(doc['todayCompleted'], 0);
      expect(doc['lastCompletedDate'], isNull);
      expect(doc.containsKey('milestone'), isFalse);
      expect(doc.containsKey('ramadan'), isFalse);
      // Who this is still travels: a name, a code and a face are not numbers.
      expect(doc['name'], 'Amira Khan');
      expect(doc['code'], 'ABC234');
      expect(doc['todayDate'], todayId, reason: 'the rules require a day id');
      expect(doc['photo'], 'B' * 6000);
    });

    test(
      'the loud document carries the numbers, the milestone and Ramadan',
      () async {
        final FriendProgress? p = await published(quiet: false);
        final Map<String, Object?> doc = p!.toMap();

        expect(doc['quiet'], isFalse);
        expect(doc['totalPrayers'], 1240);
        expect(doc['todayCompleted'], 3);
        expect(p.milestone, milestone);
        expect(
          p.ramadan,
          RamadanShare(
            fasts: 12,
            fastingToday: true,
            taraweeh: true,
            date: todayId,
          ),
        );
      },
    );

    test('outside Ramadan there is no Ramadan line, quiet or not', () async {
      final FriendProgress? p = await published(quiet: false, ramadan: false);
      expect(p!.ramadan, isNull);
      expect(p.toMap().containsKey('ramadan'), isFalse);
    });

    test('silenced() keeps nothing but the identity', () {
      final FriendProgress loud = progress(
        milestone: milestone,
        ramadan: share,
      );
      final FriendProgress quiet = loud.silenced();
      expect(quiet.quiet, isTrue);
      expect(quiet.streak, 0);
      expect(quiet.longestStreak, 0);
      expect(quiet.totalPrayers, 0);
      expect(quiet.totalTahajjud, 0);
      expect(quiet.todayCompleted, 0);
      expect(quiet.lastCompletedDate, isNull);
      expect(quiet.milestone, isNull);
      expect(quiet.ramadan, isNull);
      expect(quiet.name, loud.name);
      expect(quiet.code, loud.code);
      expect(quiet.todayDate, loud.todayDate);
      expect(quiet.streakOn(today), 0);
      expect(quiet.prayedOn(today), isFalse);
    });
  });

  // A circle's one number, computed from a synthetic run of days. The day
  // the pause covered has Fajr confirmed on it and Tahajjud ticked — a pause
  // that began in the evening — and still counts for no goal: those days do
  // not count either way, and a count is the only thing that ever leaves the
  // phone about them.
  group('circle kept', () {
    PrayerDay day(
      String dateId, {
      int completed = 0,
      bool tahajjud = false,
      bool excused = false,
    }) => PrayerDay(
      dateId: dateId,
      excused: excused,
      tahajjudPrayed: tahajjud,
      records: <PrayerId, PrayerRecord>{
        for (final PrayerId id in PrayerId.obligatory.take(completed))
          id: const PrayerRecord(status: PrayerStatus.completed),
      },
    );

    final List<PrayerDay> days = <PrayerDay>[
      day('2026-08-31', completed: 5, tahajjud: true), // before the start
      day('2026-09-01', completed: 5, tahajjud: true),
      day('2026-09-02', completed: 1), // Fajr only
      day('2026-09-03', completed: 1, tahajjud: true, excused: true),
      day('2026-09-04', tahajjud: true), // Tahajjud only
      day('2026-09-05', completed: 5),
      day('2026-09-05', completed: 5), // the same day twice counts once
      day('2026-09-11', completed: 5, tahajjud: true), // after today
    ];
    final DateTime on = DateTime(2026, 9, 10);

    Circle circle(CircleGoal goal) => Circle(
      id: 'c1',
      name: 'Fajr with the cousins',
      goal: goal,
      startsOn: '2026-09-01',
      code: 'ABC234',
      createdBy: 'me',
      members: const <String>['me', 'them'],
    );

    test('fajr counts the days Fajr was confirmed', () {
      expect(circle(CircleGoal.fajr).keptOn(days, on), 3);
    });

    test('five counts the finished days', () {
      expect(circle(CircleGoal.five).keptOn(days, on), 2);
    });

    test('tahajjud counts the nights', () {
      expect(circle(CircleGoal.tahajjud).keptOn(days, on), 2);
    });

    test('an excused day is kept for no goal, whatever is on it', () {
      final PrayerDay paused = day(
        '2026-09-03',
        completed: 5,
        tahajjud: true,
        excused: true,
      );
      for (final CircleGoal goal in CircleGoal.values) {
        expect(goal.keptOn(paused), isFalse, reason: goal.key);
        expect(circle(goal).keptOn(<PrayerDay>[paused], on), 0);
      }
    });

    test('days after the fortieth do not count', () {
      final List<PrayerDay> late = <PrayerDay>[
        day('2026-10-10', completed: 5), // the fortieth day
        day('2026-10-11', completed: 5), // the forty-first
      ];
      expect(circle(CircleGoal.five).endsOn, '2026-10-10');
      expect(circle(CircleGoal.five).keptOn(late, DateTime(2026, 12, 1)), 1);
    });

    test('days elapsed and the shared bar', () {
      final Circle c = circle(CircleGoal.fajr);
      expect(c.daysElapsed(DateTime(2026, 8, 20)), 0);
      expect(c.daysElapsed(DateTime(2026, 9, 1)), 1);
      expect(c.daysElapsed(on), 10);
      expect(c.daysElapsed(DateTime(2027, 1, 1)), Circle.length);
      expect(c.isOver(DateTime(2026, 10, 10)), isFalse);
      expect(c.isOver(DateTime(2026, 10, 11)), isTrue);
      // Three kept and two kept, over two members and ten days.
      expect(
        c.sharedFraction(const <CircleProgress>[
          CircleProgress(uid: 'me', kept: 3),
          CircleProgress(uid: 'them', kept: 2),
          CircleProgress(uid: 'stranger', kept: 40),
        ], on),
        closeTo(0.25, 1e-9),
      );
      expect(
        c.sharedFraction(const <CircleProgress>[], DateTime(2026, 8, 20)),
        0,
      );
    });

    test('round trips through a document, and refuses what it cannot read', () {
      final Circle c = circle(CircleGoal.tahajjud);
      final Circle? back = Circle.fromDoc(
        _FakeDoc('c1', <String, Object?>{
          ...c.toMap(),
          'createdAt': Timestamp.fromDate(DateTime(2026, 9, 1, 8)),
        }),
      );
      expect(back, isNotNull);
      expect(back!.goal, CircleGoal.tahajjud);
      expect(back.members, <String>['me', 'them']);
      expect(back.days, Circle.length);
      expect(back.createdAt, DateTime(2026, 9, 1, 8));
      expect(
        Circle.fromDoc(
          _FakeDoc('c2', <String, Object?>{...c.toMap(), 'goal': 'zakat'}),
        ),
        isNull,
      );
      expect(
        Circle.fromDoc(
          _FakeDoc('c3', <String, Object?>{...c.toMap(), 'startsOn': 'soon'}),
        ),
        isNull,
      );
      expect(
        CircleProgress.fromDoc(
          _FakeDoc('me', <String, Object?>{'kept': 99}),
        ).kept,
        Circle.length,
      );
    });
  });

  group('eidTodayProvider', () {
    int? eidOn(DateTime date) {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[todayProvider.overrideWithValue(date)],
      );
      addTearDown(container.dispose);
      return container.read(eidTodayProvider);
    }

    // The Gregorian dates come off the same calendar the provider reads, so
    // an adjustment to the Umm al-Qura tables moves both together.
    final DateTime fitr = HijriCalendar().hijriToGregorian(1448, 10, 1);
    final DateTime adha = HijriCalendar().hijriToGregorian(1448, 12, 10);

    test('1 Shawwal is Eid al-Fitr', () {
      expect(eidOn(fitr), 1);
      expect(fitr, DateTime(2027, 3, 9), reason: 'as the tables stand');
    });

    test('10 Dhul-Hijjah is Eid al-Adha', () {
      expect(eidOn(adha), 2);
      expect(adha, DateTime(2027, 5, 16), reason: 'as the tables stand');
    });

    test('an ordinary day is neither', () {
      expect(eidOn(today), isNull);
      expect(eidOn(fitr.add(const Duration(days: 1))), isNull);
      expect(eidOn(adha.subtract(const Duration(days: 1))), isNull);
    });

    test(
      'Ramadan is the ninth month and the greeting is keyed to the year',
      () {
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            todayProvider.overrideWithValue(
              HijriCalendar().hijriToGregorian(1448, 9, 15),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(isRamadanProvider), isTrue);
        expect(container.read(hijriYearProvider), 1448);
        expect(HijriDates.isRamadan(today), isFalse);
        expect(HijriDates.eidKey(fitr, 1), '1448-1');
        expect(HijriDates.eidKey(adha, 2), '1448-2');
      },
    );

    test('eidSentProvider remembers this Eid and not the other', () async {
      Future<bool> sent(DateTime on) async {
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            todayProvider.overrideWithValue(on),
            appUserProvider.overrideWith(
              (Ref ref) => Stream<AppUser?>.value(
                const AppUser(
                  uid: 'me',
                  displayName: 'Amira Khan',
                  email: 'amira@example.com',
                  eidSent: <String>{'1448-1'},
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(appUserProvider.future);
        return container.read(eidSentProvider);
      }

      expect(await sent(fitr), isTrue);
      expect(await sent(adha), isFalse);
      expect(await sent(today), isFalse);
    });
  });

  group('prayers together', () {
    test('is what both have prayed since the count began', () {
      expect(
        FriendMeta.together(
          myTotal: 1240,
          myStartTotal: 1200,
          theirTotal: 800,
          theirStartTotal: 790,
        ),
        50,
      );
    });

    test('is floored at zero', () {
      // A friend who has since gone quiet publishes zeros, and a total that
      // went backwards must not read as a debt.
      expect(
        FriendMeta.together(
          myTotal: 1240,
          myStartTotal: 1200,
          theirTotal: 0,
          theirStartTotal: 790,
        ),
        0,
      );
      expect(
        FriendMeta.together(
          myTotal: 5,
          myStartTotal: 5,
          theirTotal: 5,
          theirStartTotal: 5,
        ),
        0,
      );
    });

    test('the provider reads both sides and the recorded start', () async {
      Future<int?> together({
        bool meQuiet = false,
        bool themQuiet = false,
      }) async {
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            friendsUidProvider.overrideWithValue('me'),
            quietProvider.overrideWithValue(meQuiet),
            userStatsProvider.overrideWithValue(
              const UserStats(totalPrayers: 1240),
            ),
            friendsProvider.overrideWith(
              (Ref ref) => Stream<List<Friend>>.value(<Friend>[
                Friend(
                  uid: 'them',
                  name: 'Yusuf Adeyemi',
                  code: 'DEF345',
                  since: DateTime(2026, 1, 1),
                ),
              ]),
            ),
            friendProgressProvider.overrideWith(
              (Ref ref, String uid) => Stream<FriendProgress?>.value(
                FriendProgress(
                  uid: uid,
                  name: 'Yusuf Adeyemi',
                  code: 'DEF345',
                  totalPrayers: themQuiet ? 0 : 800,
                  quiet: themQuiet,
                ),
              ),
            ),
            friendMetaProvider.overrideWith(
              (Ref ref, String uid) => Stream<FriendMeta?>.value(
                FriendMeta(
                  myStartTotal: 1200,
                  theirStartTotal: 790,
                  at: DateTime(2026, 1, 2),
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(friendsProvider.future);
        await container.read(friendProgressProvider('them').future);
        await container.read(friendMetaProvider('them').future);
        return container.read(togetherProvider('them'));
      }

      expect(await together(), 50);
      expect(await together(themQuiet: true), isNull);
      expect(await together(meQuiet: true), isNull);
    });
  });

  group("Jumu'ah", () {
    test('the coming Friday is today on a Friday, else the next one', () {
      expect(Jumuah.comingFridayId(DateTime(2026, 9, 15)), '2026-09-18');
      expect(Jumuah.comingFridayId(DateTime(2026, 9, 18)), '2026-09-18');
      expect(Jumuah.comingFridayId(DateTime(2026, 9, 19)), '2026-09-25');
      expect(Jumuah.comingFridayId(DateTime(2026, 12, 31)), '2027-01-01');
    });

    test('a plan is only for the Friday it names', () {
      const Jumuah plan = Jumuah(masjid: 'Masjid al-Noor', date: '2026-09-18');
      expect(plan.isFor(DateTime(2026, 9, 15)), isTrue);
      expect(plan.isFor(DateTime(2026, 9, 18)), isTrue);
      expect(plan.isFor(DateTime(2026, 9, 19)), isFalse);
    });

    test('the name is cut to forty and read back tested', () {
      expect(Jumuah.clean('  Masjid al-Noor  '), 'Masjid al-Noor');
      expect(Jumuah.clean('m' * 60).length, Jumuah.maxLength);
      expect(Jumuah.clean('   '), '');
      expect(
        Jumuah.fromDoc(
          _FakeDoc('u', <String, Object?>{'masjid': 7, 'date': 'x'}),
        ),
        isNull,
      );
      expect(
        Jumuah.fromDoc(
          _FakeDoc('u', <String, Object?>{
            'masjid': 'Masjid al-Noor',
            'date': '2026-09-18',
            'updatedAt': Timestamp.fromDate(today),
          }),
        ),
        Jumuah(masjid: 'Masjid al-Noor', date: '2026-09-18', updatedAt: today),
      );
    });

    test('isFridayProvider', () {
      for (final (DateTime day, bool friday) in <(DateTime, bool)>[
        (DateTime(2026, 9, 18), true),
        (DateTime(2026, 9, 19), false),
      ]) {
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[todayProvider.overrideWithValue(day)],
        );
        addTearDown(container.dispose);
        expect(container.read(isFridayProvider), friday);
      }
    });
  });

  group('inbox items', () {
    InboxItem? sent(Map<String, Object?> payload) => InboxItem.fromDoc(
      _FakeDoc('i1', <String, Object?>{
        ...payload,
        'at': Timestamp.fromDate(DateTime(2026, 9, 14, 9)),
      }),
    );

    test('a verse carries the passage and nothing else', () {
      final Map<String, Object?> payload = InboxItem.payload(
        type: InboxType.verse,
        fromUid: 'them',
        fromName: 'Saad Rahman',
        comfortId: 'quran:Al-Baqarah 2:286',
      );
      expect(payload.keys, <String>{
        'type',
        'fromUid',
        'fromName',
        'at',
        'comfortId',
      });
      final InboxItem item = sent(payload)!;
      expect(item.type, InboxType.verse);
      expect(item.comfortId, 'quran:Al-Baqarah 2:286');
      expect(item.fromName, 'Saad Rahman');
      expect(item.circleId, isNull);
    });

    test('an Eid greeting carries no text at all', () {
      final Map<String, Object?> payload = InboxItem.payload(
        type: InboxType.eid,
        fromUid: 'them',
        fromName: 'Saad Rahman',
        comfortId: 'ignored',
      );
      expect(payload.keys, <String>{'type', 'fromUid', 'fromName', 'at'});
      expect(sent(payload)!.type, InboxType.eid);
    });

    test('a circle invitation carries the circle and its code', () {
      final Map<String, Object?> payload = InboxItem.payload(
        type: InboxType.circle,
        fromUid: 'them',
        fromName: 'Saad Rahman',
        circleId: 'c1',
        circleCode: 'ABC234',
      );
      expect(payload.keys, <String>{
        'type',
        'fromUid',
        'fromName',
        'at',
        'circleId',
        'circleCode',
      });
      final InboxItem item = sent(payload)!;
      expect(item.circleId, 'c1');
      expect(item.circleCode, 'ABC234');
    });

    test('what this app could not have sent is left out', () {
      expect(
        sent(<String, Object?>{
          'type': 'poke',
          'fromUid': 'them',
          'fromName': 'S',
        }),
        isNull,
      );
      expect(
        InboxItem.fromDoc(
          _FakeDoc('i2', <String, Object?>{
            'type': 'eid',
            'fromUid': 'them',
            'fromName': 'Saad',
            'at': null,
          }),
        ),
        isNull,
        reason: 'not stamped yet',
      );
      expect(
        sent(<String, Object?>{
          'type': 'eid',
          'fromUid': 'them',
          'fromName': '',
        })!.fromName,
        FriendName.fallback,
      );
    });
  });

  group('RamadanRecord', () {
    final int year = HijriDates.yearOf(today);

    test('ticks one fast per day however often it is pressed', () {
      RamadanRecord r = RamadanRecord(year: year);
      r = r.withFasted('2027-02-20', true);
      r = r.withFasted('2027-02-20', true);
      expect(r.fasts, 1);
      r = r.withFasted('2027-02-21', true);
      expect(r.fasts, 2);
      r = r.withFasted('2027-02-21', false);
      expect(r.fasts, 1);
      expect(r.fastedOn, isNull);
      expect(r.withFasted('2027-02-21', false), r, reason: 'nothing to undo');
    });

    test('taraweeh is a yes-or-no for the night', () {
      final RamadanRecord r = RamadanRecord(
        year: year,
      ).withTaraweeh('2027-02-20', true);
      expect(r.taraweehOnDay('2027-02-20'), isTrue);
      expect(r.withTaraweeh('2027-02-20', false).taraweehOn, isNull);
      expect(r.withTaraweeh('2027-02-21', false), r);
    });

    test('last year\'s thirty do not open this year at thirty', () {
      final RamadanRecord old = RamadanRecord(year: year - 1, fasts: 30);
      expect(old.forYear(year), RamadanRecord(year: year));
      expect(old.forYear(year - 1), old);
    });

    test('what friends see is derived for today only', () {
      final RamadanRecord r = RamadanRecord(
        year: year,
        fasts: 12,
        fastedOn: '2027-02-20',
        taraweehOn: '2027-02-19',
      );
      expect(
        r.share('2027-02-20'),
        const RamadanShare(
          fasts: 12,
          fastingToday: true,
          taraweeh: false,
          date: '2027-02-20',
        ),
      );
      expect(r.share('2027-02-21').fastingToday, isFalse);
    });

    test('reads back tested, never cast', () {
      expect(RamadanRecord.fromMap('ramadan'), isNull);
      expect(RamadanRecord.fromMap(<String, Object?>{'fasts': 3}), isNull);
      final RamadanRecord? back = RamadanRecord.fromMap(<String, Object?>{
        'year': 1448,
        'fasts': 45.0,
        'fastedOn': 'yesterday',
        'taraweehOn': '2027-02-20',
      });
      expect(back!.fasts, RamadanShare.maxFasts);
      expect(back.fastedOn, isNull);
      expect(back.taraweehOn, '2027-02-20');
      expect(RamadanRecord.fromMap(back.toMap()), back);
    });
  });

  group('invite links', () {
    test('the link and the share text', () {
      expect(
        inviteLinkFor('abc-234'),
        'https://adenzia04-ui.github.io/layla-pro/add.html?code=ABC234',
      );
      expect(
        inviteShareText('ABC234'),
        'Add me on Layla Pro: '
        'https://adenzia04-ui.github.io/layla-pro/add.html?code=ABC234',
      );
    });

    test('the code comes back off either kind of link', () {
      expect(InviteLink.codeFrom(Uri.parse(inviteLinkFor('ABC234'))), 'ABC234');
      expect(
        InviteLink.codeFrom(Uri.parse('layla://add?code=abc-234')),
        'ABC234',
      );
      expect(
        InviteLink.codeFrom(Uri.parse('layla:///add?code=ABC234')),
        'ABC234',
      );
    });

    test('anything else is not an invite', () {
      expect(
        InviteLink.codeFrom(
          Uri.parse('https://example.com/add.html?code=ABC234'),
        ),
        isNull,
      );
      expect(InviteLink.codeFrom(Uri.parse('layla://focus/fajr')), isNull);
      expect(InviteLink.codeFrom(Uri.parse('layla://add?code=AB')), isNull);
      expect(InviteLink.codeFrom(Uri.parse('layla://add')), isNull);
    });

    test('pendingInviteProvider starts empty', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(pendingInviteProvider), isNull);
      container.read(pendingInviteProvider.notifier).state = 'ABC234';
      expect(container.read(pendingInviteProvider), 'ABC234');
    });
  });

  // The shapes, pinned. Every one of these documents is read by somebody
  // else, and the rules refuse any key outside the set — so a key added
  // here without a rule is a silent refusal, and a key about the pause is
  // the one thing this whole feature must never carry.
  group('what leaves the phone', () {
    const Set<String> forbidden = <String>{'cycle', 'excused', 'gender'};

    void neverCarries(Map<String, Object?> doc) {
      for (final String key in doc.keys) {
        expect(forbidden.contains(key), isFalse, reason: key);
      }
    }

    test('the scoreboard', () {
      final Map<String, Object?> doc = progress(
        quiet: true,
        milestone: milestone,
        ramadan: share,
      ).toMap();
      neverCarries(doc);
      expect(doc.keys.toSet(), <String>{
        'name',
        'code',
        'streak',
        'longestStreak',
        'totalPrayers',
        'totalTahajjud',
        'todayCompleted',
        'todayDate',
        'lastCompletedDate',
        'photo',
        'quiet',
        'milestone',
        'ramadan',
      });
      expect((doc['milestone']! as Map<String, Object?>).keys, <String>{
        'key',
        'at',
      });
      expect((doc['ramadan']! as Map<String, Object?>).keys, <String>{
        'fasts',
        'fastingToday',
        'taraweeh',
        'date',
      });
    });

    test('a circle, a count, a start and a plan', () {
      final Map<String, Object?> circle = const Circle(
        id: 'c1',
        name: 'Fajr with the cousins',
        goal: CircleGoal.fajr,
        startsOn: '2026-09-01',
        code: 'ABC234',
        createdBy: 'me',
        members: <String>['me'],
      ).toMap();
      neverCarries(circle);
      expect(circle.keys.toSet(), <String>{
        'name',
        'goal',
        'startsOn',
        'days',
        'code',
        'createdBy',
        'members',
        'createdAt',
      });
      expect(circle['days'], 40);

      final Map<String, Object?> kept = const CircleProgress(
        uid: 'me',
        kept: 3,
      ).toMap();
      neverCarries(kept);
      expect(kept.keys.toSet(), <String>{'kept', 'updatedAt'});

      final Map<String, Object?> meta = const FriendMeta(
        myStartTotal: 1,
        theirStartTotal: 2,
      ).toMap();
      neverCarries(meta);
      expect(meta.keys.toSet(), <String>{
        'myStartTotal',
        'theirStartTotal',
        'at',
      });

      final Map<String, Object?> plan = const Jumuah(
        masjid: 'Masjid al-Noor',
        date: '2026-09-18',
      ).toMap();
      neverCarries(plan);
      expect(plan.keys.toSet(), <String>{'masjid', 'date', 'updatedAt'});
    });
  });
}

// ignore: subtype_of_sealed_class
/// The one thing `fromDoc` actually reads: an id and a map.
///
/// A real `DocumentSnapshot` cannot be built without Firestore, and the rest
/// of its surface is never touched here — so it is left to `noSuchMethod`,
/// which throws loudly if this test ever starts leaning on it. See
/// `friends_progress_test.dart` for why the seal is worth stepping past here.
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
