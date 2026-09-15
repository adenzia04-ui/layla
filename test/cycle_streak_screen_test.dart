import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/core/widgets/app_scaffold.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/features/cycle/domain/cycle.dart';
import 'package:noor/features/prayer_times/application/prayer_times_controller.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/application/streak_controller.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';
import 'package:noor/features/streaks/presentation/streak_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

/// The prayer pause as the streak screen draws it.
///
/// This is the screen a woman opens *to check the pause did not cost her
/// anything*, so it is the last place that may imply a debt. Three separate
/// readings on it could each do that, and all three are reached from the day
/// document rather than from the profile, which is why they are tested here
/// through the real screen rather than against the domain:
///
/// * the five rows under "Today's progress", which say "Not yet" — five
///   prayers still expected of her — unless the pause is applied to today;
/// * the badge on an opened day, which would say "1 of 5 confirmed" in amber
///   on a day the pause began part-way through, presenting the four she was
///   never asked to pray as outstanding;
/// * the year bar, whose denominator is five a day unless the paused days are
///   taken out of it — the difference between "100%" and a permanent shortfall
///   for a woman who prayed everything she owed.
///
/// There is no qada for these prayers (Sahih Muslim 335). The control tests in
/// each group — an ordinary day still reads "Not yet", a missed day still reads
/// "Missed", an unpaused year is still five a day — are here so that none of
/// the above can be satisfied by a screen that has simply stopped saying
/// anything.
void main() {
  setUpAll(loadNoorFonts);

  /// Fixed so the year arithmetic is a known number: 15 September 2026 is day
  /// 258 of a 365-day year.
  final DateTime today = DateTime(2026, 9, 15);
  const int dayOfYear = 258;
  final String todayId = Fmt.dayId(today);

  /// Yesterday — the day the tests below open from the year grid.
  final DateTime opened = DateTime(2026, 9, 14);
  final String openedId = Fmt.dayId(opened);

  final int all = PrayerId.obligatory.length;

  PrayerDay perfect(String id) => PrayerDay(
    dateId: id,
    records: <PrayerId, PrayerRecord>{
      for (final PrayerId p in PrayerId.obligatory)
        p: const PrayerRecord(status: PrayerStatus.completed),
    },
  );

  /// A day the pause covered from its start, as the catch-up leaves it.
  PrayerDay pausedAllDay(String id) => PrayerDay(
    dateId: id,
    excused: true,
    records: <PrayerId, PrayerRecord>{
      for (final PrayerId p in PrayerId.obligatory)
        p: const PrayerRecord(status: PrayerStatus.excused),
    },
  );

  /// Fajr prayed that morning, the pause from Dhuhr — which is how most of
  /// them begin, and the only shape that reaches the `n > 0` arm of the badge.
  PrayerDay pausedFromDhuhr(String id) => PrayerDay(
    dateId: id,
    excused: true,
    records: <PrayerId, PrayerRecord>{
      PrayerId.fajr: const PrayerRecord(status: PrayerStatus.completed),
      for (final PrayerId p in PrayerId.obligatory.skip(1))
        p: const PrayerRecord(status: PrayerStatus.excused),
    },
  );

  /// An ordinary day that went wrong: Fajr answered "I did not pray this one",
  /// and nothing after it.
  PrayerDay missedFajr(String id) => PrayerDay(
    dateId: id,
    records: const <PrayerId, PrayerRecord>{
      PrayerId.fajr: PrayerRecord(status: PrayerStatus.missed),
    },
  );

  StreakHistory historyOf(Map<String, PrayerDay> days) =>
      StreakHistory(year: 2026, days: days);

  /// The year so far with a week of it paused: every other day finished, so
  /// everything she owed was confirmed and the bar should read 100%.
  StreakHistory yearWithAPausedWeek() {
    final Map<String, PrayerDay> days = <String, PrayerDay>{};
    for (int i = 0; i < dayOfYear; i++) {
      final String id = Fmt.dayId(DateTime(2026, 1, 1 + i));
      // 1–7 September: i is zero-based, so 243..249.
      days[id] = i >= 243 && i <= 249 ? pausedAllDay(id) : perfect(id);
    }
    return historyOf(days);
  }

  /// The screen with every provider it watches stubbed — no Firebase, no
  /// emulator, no clock.
  ///
  /// [day] is today's document *as Firestore holds it*, deliberately separate
  /// from [cycle]: during a pause the profile knows first and the day document
  /// only catches up after a network round trip, and the gap between them is
  /// every cold open from the second day of a pause onwards.
  Future<void> pumpStreak(
    WidgetTester tester, {
    required StreakHistory history,
    PrayerDay? day,
    Cycle cycle = Cycle.none,
    String? gender = Gender.sister,
  }) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(PrefsService(prefs)),
          todayProvider.overrideWithValue(today),
          // The profile itself, not the values derived from it: `isSister`
          // and `cycleActive` are both read off this document in the running
          // app, and overriding them separately would test the screen against
          // a wiring that does not exist.
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              AppUser(
                uid: 'u1',
                displayName: 'Maryam',
                email: 'maryam@example.com',
                gender: gender,
                cycle: cycle,
                stats: UserStats(
                  currentStreak: 12,
                  longestStreak: 30,
                  totalPrayers: 1255,
                  lastCompletedDate: todayId,
                ),
              ),
            ),
          ),
          todayPrayerDayProvider.overrideWith(
            (Ref ref) =>
                Stream<PrayerDay>.value(day ?? PrayerDay.empty(todayId)),
          ),
          streakHistoryProvider.overrideWith(
            (Ref ref) => Stream<StreakHistory>.value(history),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const StreakScreen(),
        ),
      ),
    );
    // One frame to subscribe to the streams, one for them to land.
    await tester.pump();
    await tester.pump();
  }

  /// Opens a day in the year card by walking back from today.
  ///
  /// The arrows rather than the dots: a dot is four points across and picked
  /// by coordinate, so a tap that landed a day either side would pass or fail
  /// for reasons that have nothing to do with what is being tested. With
  /// nothing open the first press opens today, so [steps] of 2 opens
  /// yesterday.
  ///
  /// Not `pumpAndSettle`: the card crossfades and the page grows to fit, and
  /// the ornament band above is repainted every frame — so the pumps are
  /// explicit and long enough for both transitions.
  Future<void> openDayBack(WidgetTester tester, int steps) async {
    final Finder back = find.byTooltip('A day back');
    for (int i = 0; i < steps; i++) {
      await tester.ensureVisible(back);
      await tester.pump();
      await tester.tap(back);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  /// The card for whichever day is open — the one holding the Close button.
  Finder openDay() => find
      .ancestor(of: find.byTooltip('Close'), matching: find.byType(NightCard))
      .first;

  /// The pill in that card's header: the reading the excused arm decides.
  ///
  /// Found by its style rather than by its words. The five rows underneath can
  /// carry the very same word — "Paused" is exactly what they say on a paused
  /// day — so a text finder could not tell a correct header from a missing
  /// one, and `AppType.label` is used nowhere else inside this card.
  Text openDayBadge(WidgetTester tester) {
    final Iterable<Text> pills = tester
        .widgetList<Text>(
          find.descendant(of: openDay(), matching: find.byType(Text)),
        )
        .where(
          (Text t) =>
              t.style?.fontSize == 11 && t.style?.fontWeight == FontWeight.w600,
        );
    expect(pills, hasLength(1), reason: 'one badge in the open day header');
    return pills.single;
  }

  /// Every colour the open day is drawn in, text and icons alike.
  Iterable<Color?> openDayColours(WidgetTester tester) => <Color?>[
    ...tester
        .widgetList<Text>(
          find.descendant(of: openDay(), matching: find.byType(Text)),
        )
        .map((Text t) => t.style?.color),
    ...tester
        .widgetList<Icon>(
          find.descendant(of: openDay(), matching: find.byType(Icon)),
        )
        .map((Icon i) => i.color),
  ];

  Iterable<Color?> iconColours(WidgetTester tester) =>
      tester.widgetList<Icon>(find.byType(Icon)).map((Icon i) => i.color);

  Finder inOpenDay(Finder matching) =>
      find.descendant(of: openDay(), matching: matching);

  group("today's five rows, while the pause is on", () {
    testWidgets('read Paused, never "Not yet"', (WidgetTester tester) async {
      // The document has not caught up yet — all five still read pending —
      // which is the state a cold open finds from the second day onwards.
      // Keyed to the document alone, this screen would ask her for five
      // prayers she does not owe.
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{}),
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expect(find.text('Paused'), findsNWidgets(5));
      expect(find.text('Not yet'), findsNothing);
      expect(find.text('Not confirmed'), findsNothing);
      expect(find.text('Missed'), findsNothing);
      // Neither of the two colours that mean something is outstanding.
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
      expect(iconColours(tester), isNot(contains(AppColors.amber)));
    });

    testWidgets('read the same once the catch-up write has landed', (
      WidgetTester tester,
    ) async {
      // The invariant behind the test above: what she sees must not depend on
      // whether a write she never asked about has come back yet.
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{todayId: pausedAllDay(todayId)}),
        day: pausedAllDay(todayId),
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expect(find.text('Paused'), findsNWidgets(5));
      expect(find.text('Not yet'), findsNothing);
    });

    testWidgets('take down a cross left by a prayer missed before it began', (
      WidgetTester tester,
    ) async {
      // She answered honestly at nine and the pause began at ten. The cross
      // was true when it was drawn and is not any more.
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{}),
        day: missedFajr(todayId),
        cycle: const Cycle(startedOn: '2026-09-15'),
      );

      expect(find.text('Paused'), findsNWidgets(5));
      expect(find.text('Missed'), findsNothing);
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
    });

    testWidgets('still ask for the day when no pause is on', (
      WidgetTester tester,
    ) async {
      // The control. A screen that said "Paused" over every unprayed day would
      // pass every test above and be useless.
      await pumpStreak(tester, history: historyOf(<String, PrayerDay>{}));

      expect(find.text('Not yet'), findsNWidgets(5));
      expect(find.text('Paused'), findsNothing);
    });
  });

  group('a day opened from the year', () {
    testWidgets('a paused day reads Paused, not "Nothing recorded"', (
      WidgetTester tester,
    ) async {
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{
          openedId: pausedAllDay(openedId),
        }),
      );
      await openDayBack(tester, 2);

      final Text badge = openDayBadge(tester);
      expect(badge.data, 'Paused');
      expect(badge.style?.color, AppColors.mistFaint);
      // The badge and the five rows below it, all saying the one word.
      expect(inOpenDay(find.text('Paused')), findsNWidgets(all + 1));
      expect(inOpenDay(find.text('Nothing recorded')), findsNothing);
      expect(inOpenDay(find.text('Not confirmed')), findsNothing);
      expect(inOpenDay(find.text('Missed')), findsNothing);
      expect(openDayColours(tester), isNot(contains(AppColors.rose)));
      expect(openDayColours(tester), isNot(contains(AppColors.amber)));
    });

    testWidgets('a day the pause began part-way through is not "1 of 5 '
        'confirmed"', (WidgetTester tester) async {
      // The reason the excused arm goes first. This day has one prayer
      // confirmed, so every counting arm below would happily claim it and put
      // the four she was never asked to pray on screen as a shortfall, in
      // amber, on the screen she opened to check nothing had been lost.
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{
          openedId: pausedFromDhuhr(openedId),
        }),
      );
      await openDayBack(tester, 2);

      final Text badge = openDayBadge(tester);
      expect(badge.data, 'Paused');
      expect(badge.style?.color, AppColors.mistFaint);
      expect(inOpenDay(find.text('1 of $all confirmed')), findsNothing);
      expect(inOpenDay(find.textContaining('confirmed')), findsNothing);
      expect(openDayColours(tester), isNot(contains(AppColors.amber)));

      // And the Fajr she did pray is still hers: the pause hides nothing she
      // earned, it only stops the rest being counted against her.
      expect(inOpenDay(find.text('Confirmed')), findsOneWidget);
      expect(inOpenDay(find.text('Paused')), findsNWidgets(all));
      expect(openDayColours(tester), contains(AppColors.emerald));
    });

    testWidgets('a missed day still reads as missed', (
      WidgetTester tester,
    ) async {
      // The control for this group: the excused arm must not have swallowed
      // the ordinary day that genuinely went wrong.
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{openedId: missedFajr(openedId)}),
      );
      await openDayBack(tester, 2);

      final Text badge = openDayBadge(tester);
      expect(badge.data, 'Missed');
      expect(badge.style?.color, AppColors.rose);
      expect(inOpenDay(find.text('Paused')), findsNothing);
      expect(openDayColours(tester), contains(AppColors.rose));
    });

    testWidgets('a finished day is still a perfect day', (
      WidgetTester tester,
    ) async {
      await pumpStreak(
        tester,
        history: historyOf(<String, PrayerDay>{openedId: perfect(openedId)}),
      );
      await openDayBack(tester, 2);

      expect(openDayBadge(tester).data, 'A perfect day');
      expect(inOpenDay(find.text('Confirmed')), findsNWidgets(all));
    });
  });

  group("the year's percentage", () {
    /// The sentence under the year bar, whatever number it carries.
    Finder bar(int pct) =>
        find.text("$pct% of this year's prayers confirmed so far");

    testWidgets('counts what was owed, not five times every day', (
      WidgetTester tester,
    ) async {
      final StreakHistory history = yearWithAPausedWeek();
      final int owed = history.owedPrayers(dayOfYear);
      final int pct = (history.totalConfirmed / owed * 100).round();
      // What the bar would read if the paused week were still in the
      // denominator — a woman who prayed every prayer she owed, told she is
      // short, for as long as she uses the app.
      final int naive = (history.totalConfirmed / (dayOfYear * all) * 100)
          .round();

      expect(owed, lessThan(dayOfYear * all), reason: 'a week owed nothing');
      expect(pct, 100);
      expect(naive, isNot(pct), reason: 'the two readings must differ here');

      await pumpStreak(tester, history: history, day: perfect(todayId));

      expect(bar(pct), findsOneWidget);
      expect(bar(naive), findsNothing);
      expect(find.text('Day $dayOfYear of 365'), findsOneWidget);
    });

    testWidgets('is still five a day when nothing was paused', (
      WidgetTester tester,
    ) async {
      // The control: the denominator only ever shrinks by what the pause
      // covered, so an ordinary year reads exactly as it always did.
      final Map<String, PrayerDay> days = <String, PrayerDay>{};
      for (int i = 0; i < 129; i++) {
        final String id = Fmt.dayId(DateTime(2026, 1, 1 + i));
        days[id] = perfect(id);
      }
      final StreakHistory history = historyOf(days);

      expect(history.owedPrayers(dayOfYear), dayOfYear * all);

      await pumpStreak(tester, history: history);

      expect(bar(50), findsOneWidget);
    });
  });
}
