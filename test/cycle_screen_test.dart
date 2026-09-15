import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/theme/app_spacing.dart';
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/core/widgets/app_button.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/core/utils/result.dart';
import 'package:noor/features/cycle/application/cycle_controller.dart';
import 'package:noor/features/cycle/data/cycle_repository.dart';
import 'package:noor/features/cycle/domain/cycle.dart';
import 'package:noor/features/cycle/presentation/cycle_pause_control.dart';
import 'package:noor/features/home/presentation/widgets/prayer_choice_card.dart';
import 'package:noor/features/home/presentation/widgets/today_progress_card.dart';
import 'package:noor/features/onboarding/domain/journey_answers.dart';
import 'package:noor/features/prayer_lock/domain/prayer_session.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_sizes.dart';

/// The prayer pause on the home screen.
///
/// Two things are being protected here and they pull in opposite directions.
/// One is that a woman who has answered "sister" can reach the pause without
/// hunting for it. The other — the heavier one — is that nobody else ever sees
/// that the feature exists: not a brother, not somebody who skipped the
/// question, not a friend, not a person glancing at the phone. The absence
/// tests below therefore assert on the *widget types* as well as the words,
/// because a control rendered as an empty box is still a control in the tree,
/// and "it renders nothing" is not the same promise as "it is not there".
void main() {
  /// Asr is in, unanswered — the ordinary state the pause row sits under.
  final PrayerSession session = PrayerSession(
    prayer: PrayerId.asr,
    startedAt: DateTime(2026, 9, 15, 16, 32),
    endsAt: DateTime(2026, 9, 15, 17, 2),
    status: PrayerStatus.pending,
  );

  final DateTime now = DateTime(2026, 9, 15, 17, 5);

  const PrayerDay ordinaryDay = PrayerDay(
    dateId: '2026-09-15',
    records: <PrayerId, PrayerRecord>{
      PrayerId.fajr: PrayerRecord(status: PrayerStatus.completed),
      PrayerId.dhuhr: PrayerRecord(status: PrayerStatus.completed),
    },
  );

  /// A day the pause covers, as the catch-up leaves it: five excused records
  /// and the day itself flagged, so the card is exercised the way it actually
  /// renders rather than with a day that still looks unprayed.
  final PrayerDay excusedDay = PrayerDay(
    dateId: '2026-09-15',
    excused: true,
    records: <PrayerId, PrayerRecord>{
      for (final PrayerId id in PrayerId.obligatory)
        id: const PrayerRecord(status: PrayerStatus.excused),
    },
  );

  AppUser profile({required String? gender, Cycle cycle = Cycle.none}) =>
      AppUser(
        uid: 'u1',
        displayName: 'Maryam',
        email: 'maryam@example.com',
        gender: gender,
        cycle: cycle,
      );

  /// Home's Today's Progress card, wired exactly the way `home_screen.dart`
  /// wires it — the real [buildCycleChoices], the real providers behind it.
  ///
  /// [profileGender] is what the account says; [deviceGender] is the onboarding
  /// answer still on the phone. They are separate because the profile copy is
  /// the one that survives signing out and the device copy is the fallback for
  /// everyone who onboarded before the answer was ever written to Firestore.
  Future<_FakeCycleController> pump(
    WidgetTester tester, {
    String? profileGender,
    String? deviceGender,
    Cycle cycle = Cycle.none,
    bool withSession = true,
    PrayerDay? day,
    Device device = const Device(
      'iPhone 14',
      Size(390, 844),
      3,
      EdgeInsets.only(top: 47, bottom: 34),
    ),
    double textScale = 1.0,
    // When given, the real [CycleController] runs against this repository
    // instead of the counting fake. The fake is the right tool for "did the
    // screen call start once", but it cannot see the controller itself — and
    // the controller is auto-disposed, so whether a caller holds a
    // subscription across the await decides whether the write's result ever
    // comes back at all.
    CycleRepository? repo,
  }) async {
    useDevice(tester, device);

    SharedPreferences.setMockInitialValues(<String, Object>{
      if (deviceGender != null)
        'journey_answers': JourneyAnswers(gender: deviceGender).encode(),
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final _FakeCycleController fake = _FakeCycleController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(PrefsService(prefs)),
          // The profile itself rather than `cycleProvider` and
          // `isSisterProvider`: both are derived from this document in the
          // running app, and overriding the derived values would test the
          // widgets against a wiring that does not exist.
          appUserProvider.overrideWith(
            (Ref ref) => Stream<AppUser?>.value(
              profile(gender: profileGender, cycle: cycle),
            ),
          ),
          if (repo == null)
            cycleControllerProvider.overrideWith(() => fake)
          else
            cycleRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: asDevice(
            device: device,
            textScale: textScale,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(Insets.page),
                children: <Widget>[
                  Consumer(
                    builder: (BuildContext context, WidgetRef ref, _) =>
                        TodayProgressCard(
                          // Through the real `cycleDayFor`, exactly as
                          // `home_screen.dart` passes it: the summary at the
                          // top of this card and the pause panel at the bottom
                          // read two different sources, and this is the
                          // function that keeps them agreeing.
                          day: cycleDayFor(
                            ref,
                            day ?? (cycle.isActive ? excusedDay : ordinaryDay),
                          ),
                          currentStreak: 11,
                          choices: buildCycleChoices(
                            ref,
                            now: now,
                            choices: withSession
                                ? PrayerChoiceCard(session: session)
                                : null,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // One frame to subscribe to the profile stream, one for it to land.
    await tester.pump();
    await tester.pump();
    return fake;
  }

  /// Advances past a sheet transition.
  ///
  /// Not `pumpAndSettle`: the card's bead strand breathes on a controller that
  /// repeats for as long as the card is on screen, so nothing on this screen is
  /// ever "settled" and `pumpAndSettle` simply times out after ten seconds.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Scrolls [finder] into view before tapping it.
  ///
  /// At 1.3x Dynamic Type on an SE the card is taller than the phone, so the
  /// control under test is genuinely below the fold — a bare `tap` there hits
  /// whatever happens to be at those coordinates and passes for the wrong
  /// reason, or misses and warns.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle(tester);
  }

  /// The neutral dash a bead carries on a day the pause covers.
  ///
  /// The bead itself is private to the card, so what it draws is read the way
  /// the rest of these tests read it — off the icon. A dash is the whole point:
  /// the bead that says "missed" is the one thing a paused day must not look
  /// like.
  Finder dashes(WidgetTester tester) => find.byWidgetPredicate(
    (Widget w) =>
        w is Icon &&
        w.icon == Icons.remove_rounded &&
        w.color == AppColors.mistFaint,
  );

  Iterable<Color?> iconColours(WidgetTester tester) =>
      tester.widgetList<Icon>(find.byType(Icon)).map((Icon icon) => icon.color);

  /// Every trace of the feature, by type and by word.
  void expectNoTrace() {
    expect(find.byType(CyclePauseRow), findsNothing);
    expect(find.byType(CyclePausedPanel), findsNothing);
    expect(find.text('Pause prayers for these days'), findsNothing);
    expect(find.text('Prayers are paused'), findsNothing);
    expect(find.textContaining('period'), findsNothing);
  }

  group('who the pause is offered to', () {
    testWidgets('a sister gets the quiet row under her choices', (
      WidgetTester tester,
    ) async {
      await pump(tester, profileGender: Gender.sister);

      expect(find.byType(CyclePauseRow), findsOneWidget);
      expect(find.text('Pause prayers for these days'), findsOneWidget);
      // Under the choices, not instead of them.
      expect(find.text('I have prayed'), findsOneWidget);
      expect(find.text('I did not pray this one'), findsOneWidget);
    });

    testWidgets('a brother sees no trace of it', (WidgetTester tester) async {
      await pump(tester, profileGender: Gender.brother);

      expectNoTrace();
      expect(find.text('I have prayed'), findsOneWidget);
    });

    testWidgets('an unanswered gender sees no trace of it', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expectNoTrace();
      expect(find.text('I have prayed'), findsOneWidget);
    });

    testWidgets('the onboarding answer carries someone who signed up before '
        'the profile held a gender', (WidgetTester tester) async {
      await pump(tester, deviceGender: Gender.sister);

      expect(find.byType(CyclePauseRow), findsOneWidget);
    });

    testWidgets('the profile wins over a stale answer left on the phone', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.brother,
        deviceGender: Gender.sister,
      );

      expectNoTrace();
    });

    testWidgets('a brother sees nothing even if a pause is somehow stored', (
      WidgetTester tester,
    ) async {
      // Not a state the app can produce. Asserted anyway, because the cost of
      // being wrong is showing a man a pause panel with a day count on it, and
      // the gender check is the only thing standing between those two facts.
      await pump(
        tester,
        profileGender: Gender.brother,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expectNoTrace();
      expect(find.textContaining('Day '), findsNothing);
    });
  });

  group('while the pause is on', () {
    testWidgets('it replaces the prayer choices and counts the days', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expect(find.byType(CyclePausedPanel), findsOneWidget);
      expect(find.text('Prayers are paused'), findsOneWidget);
      expect(find.text('Day 3'), findsOneWidget);

      // The three answers are meaningless on a day nothing is recorded on, and
      // "I did not pray this one" is worse than meaningless: it offers to mark
      // a prayer missed that was never owed.
      expect(find.byType(PrayerChoiceCard), findsNothing);
      expect(find.text('I have prayed'), findsNothing);
      expect(find.text('I will pray when I am home'), findsNothing);
      expect(find.text('I did not pray this one'), findsNothing);

      // The row into the pause is gone too; there is one control now.
      expect(find.byType(CyclePauseRow), findsNothing);
      expect(
        find.widgetWithText(GhostButton, 'Resume prayers'),
        findsOneWidget,
      );
    });

    testWidgets('the streak it is protecting is still on show', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expect(find.text('11 days'), findsOneWidget);
      // And the count that would otherwise read "0 of 5 confirmed" over a day
      // she was never asked to pray.
      expect(find.textContaining('confirmed'), findsNothing);
    });

    testWidgets('a short pause is not questioned', (WidgetTester tester) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      expect(find.textContaining('Still paused?'), findsNothing);
    });

    testWidgets('day fourteen is not questioned — three schools put the '
        'maximum at fifteen', (WidgetTester tester) async {
      // The timing is the ruling, whatever the wording says. Asking here would
      // tell a woman following the Shafi'i, Hanbali or Maliki position, by the
      // mere fact of asking, that she was past what is expected of her.
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-02'),
      );

      expect(find.text('Day 14'), findsOneWidget);
      expect(find.textContaining('Still paused?'), findsNothing);
    });

    testWidgets('the question stops after a couple of days rather than '
        'following her', (WidgetTester tester) async {
      // "May ask once" is the contract. A question derived from the day count
      // alone would sit on this card every time she opened the app, for as
      // long as the pause ran — pressure to end something only she can end, in
      // the one place a passer-by can read it.
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-08-28'),
      );

      expect(find.text('Day 19'), findsOneWidget);
      expect(find.textContaining('Still paused?'), findsNothing);
      expect(find.byType(CyclePausedPanel), findsOneWidget);
    });

    testWidgets('a long one is asked about once, and never ended for her', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        // Day 16, past every school's maximum.
        cycle: const Cycle(startedOn: '2026-08-31'),
      );

      expect(find.text('Day 16'), findsOneWidget);
      expect(find.textContaining('Still paused?'), findsOneWidget);
      // Asking is the whole of it: the pause is still on, and the only way out
      // is still the button she presses herself.
      expect(find.byType(CyclePausedPanel), findsOneWidget);
      expect(
        find.widgetWithText(GhostButton, 'Resume prayers'),
        findsOneWidget,
      );
    });

    testWidgets('it shows even when no prayer window is open', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        withSession: false,
      );

      expect(find.byType(CyclePausedPanel), findsOneWidget);
    });

    testWidgets('the row shows on its own when no prayer window is open', (
      WidgetTester tester,
    ) async {
      await pump(tester, profileGender: Gender.sister, withSession: false);

      expect(find.byType(CyclePauseRow), findsOneWidget);
      expect(find.byType(PrayerChoiceCard), findsNothing);
    });
  });

  /// The gap between the two things that say a day is paused.
  ///
  /// The profile knows the moment the app opens; the day document only says so
  /// once `cycleCatchUpProvider` has written it, which is a network round trip
  /// away and, offline, may not happen at all this session. That gap is not an
  /// edge case — it is every cold open from the second day of a pause onwards,
  /// which is most of them.
  ///
  /// So the card is asked here for the one state the rest of this file never
  /// produces: the pause on, the day not yet marked. Both of these lines are
  /// the ones this feature exists to prevent, and keying them to the slower of
  /// the two signals is what let them through.
  group('before the catch-up has marked today', () {
    /// Today as a fresh open finds it during a pause: nothing written yet, so
    /// all five still read pending and the day is not flagged.
    const PrayerDay unmarkedDay = PrayerDay(dateId: '2026-09-15');

    testWidgets('does not tell her she has confirmed 0 of 5', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        day: unmarkedDay,
      );

      expect(find.byType(CyclePausedPanel), findsOneWidget);
      expect(find.textContaining('confirmed'), findsNothing);
    });

    testWidgets('draws the strand as paused, not as five prayers to go', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        day: unmarkedDay,
      );

      // Five quiet dashes. A pending bead is the "go and pray this one" mark —
      // one of them breathes to draw the eye — and the strand must not be
      // asking for five prayers directly above the words "not owed".
      expect(dashes(tester), findsNWidgets(PrayerId.obligatory.length));
      expect(iconColours(tester), isNot(contains(AppColors.rose)));
    });

    testWidgets('takes down a cross left by a prayer missed that morning', (
      WidgetTester tester,
    ) async {
      // She answered honestly at nine and the pause began at ten. The cross
      // was true when it was drawn and is not any more: nothing that day was
      // owed. Leaving it up would contradict the panel directly below it, and
      // it is the one mark this feature exists to keep off a paused day.
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-15'),
        day: const PrayerDay(
          dateId: '2026-09-15',
          records: <PrayerId, PrayerRecord>{
            PrayerId.fajr: PrayerRecord(status: PrayerStatus.missed),
          },
        ),
      );

      expect(iconColours(tester), isNot(contains(AppColors.rose)));
      expect(dashes(tester), findsNWidgets(PrayerId.obligatory.length));
    });

    testWidgets('looks the same as it does once the write has landed', (
      WidgetTester tester,
    ) async {
      // The invariant behind both tests above, stated once: what she sees must
      // not depend on whether a write she never asked about has come back yet.
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        day: unmarkedDay,
      );
      final int beforeCatchUp = dashes(tester).evaluate().length;
      final bool confirmedBefore = find
          .textContaining('confirmed')
          .evaluate()
          .isNotEmpty;

      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        day: excusedDay,
      );

      expect(beforeCatchUp, dashes(tester).evaluate().length);
      expect(
        confirmedBefore,
        find.textContaining('confirmed').evaluate().isNotEmpty,
      );
    });
  });

  group('starting it', () {
    testWidgets('the row opens a sheet that says what it will do', (
      WidgetTester tester,
    ) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
      );

      await tap(tester, find.text('Pause prayers for these days'));

      expect(find.text('Pause prayers for these days?'), findsOneWidget);
      // The four promises the sheet exists to make.
      expect(find.text('Nothing is owed'), findsOneWidget);
      expect(find.text('Reminders stop'), findsOneWidget);
      expect(find.text('Your streak is kept'), findsOneWidget);
      expect(find.text('Nobody can tell'), findsOneWidget);
      // Nothing has happened yet.
      expect(fake.starts, 0);
    });

    testWidgets('confirming starts it exactly once', (
      WidgetTester tester,
    ) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
      );

      await tap(tester, find.text('Pause prayers for these days'));
      await tap(tester, find.widgetWithText(PrimaryButton, 'Pause prayers'));

      expect(fake.starts, 1);
      expect(fake.ends, 0);
    });

    testWidgets('backing out starts nothing', (WidgetTester tester) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
      );

      await tap(tester, find.text('Pause prayers for these days'));
      await tap(tester, find.widgetWithText(GhostButton, 'Not now'));

      expect(fake.starts, 0);
    });
  });

  group('ending it', () {
    testWidgets('the button asks before it ends anything', (
      WidgetTester tester,
    ) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      await tap(tester, find.widgetWithText(GhostButton, 'Resume prayers'));

      expect(find.text('Resume prayers?'), findsOneWidget);
      expect(fake.ends, 0);
    });

    testWidgets('confirming ends it exactly once', (WidgetTester tester) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      await tap(tester, find.widgetWithText(GhostButton, 'Resume prayers'));
      // The sheet's own confirm — the card's button is the ghost one, and both
      // carry the same words.
      await tap(tester, find.widgetWithText(PrimaryButton, 'Resume prayers'));

      expect(fake.ends, 1);
      expect(fake.starts, 0);
    });

    testWidgets('backing out leaves it on', (WidgetTester tester) async {
      final _FakeCycleController fake = await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
      );

      await tap(tester, find.widgetWithText(GhostButton, 'Resume prayers'));
      await tap(tester, find.widgetWithText(GhostButton, 'Stay paused'));

      expect(fake.ends, 0);
      expect(find.byType(CyclePausedPanel), findsOneWidget);
    });
  });

  /// The controller itself, not a stand-in for it.
  ///
  /// Every test above overrides `cycleControllerProvider`, which is exactly
  /// what makes them readable — and exactly what made a whole class of bug
  /// invisible. The real controller is auto-disposed; a widget that reaches it
  /// with a bare `ref.read` holds no subscription, so Riverpod throws the
  /// notifier away on the next microtask and the `state =` after its await
  /// lands on a dead element. The pause still began — the write was already in
  /// flight — so nothing on screen said otherwise, while the bool that decides
  /// whether she is told it failed never arrived.
  group('the real controller', () {
    testWidgets('starting one survives the write and reports success', (
      WidgetTester tester,
    ) async {
      final _FakeCycleRepo repo = _FakeCycleRepo();
      await pump(tester, profileGender: Gender.sister, repo: repo);

      await tap(tester, find.text('Pause prayers for these days'));
      await tap(tester, find.widgetWithText(PrimaryButton, 'Pause prayers'));
      await tester.pump(const Duration(milliseconds: 60));

      expect(repo.starts, 1);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('could not be saved'), findsNothing);
    });

    testWidgets('a start that fails says so', (WidgetTester tester) async {
      // The asymmetry this exists for: she has just read a sheet promising
      // nothing is owed and reminders stop. Silence here means the reminders
      // keep firing, the shield keeps rising, the day stays answerable — and
      // the streak she was told was safe breaks.
      final _FakeCycleRepo repo = _FakeCycleRepo(fails: true);
      await pump(tester, profileGender: Gender.sister, repo: repo);

      await tap(tester, find.text('Pause prayers for these days'));
      await tap(tester, find.widgetWithText(PrimaryButton, 'Pause prayers'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(
        find.text('That could not be saved. Your prayers are not paused yet.'),
        findsOneWidget,
      );
    });

    testWidgets('an end that fails says so too', (WidgetTester tester) async {
      final _FakeCycleRepo repo = _FakeCycleRepo(fails: true);
      await pump(
        tester,
        profileGender: Gender.sister,
        cycle: const Cycle(startedOn: '2026-09-13'),
        repo: repo,
      );

      await tap(tester, find.widgetWithText(GhostButton, 'Resume prayers'));
      await tap(tester, find.widgetWithText(PrimaryButton, 'Resume prayers'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(
        find.text('That could not be saved. Prayers are still paused.'),
        findsOneWidget,
      );
    });
  });

  // Both states on every phone the app ships to, at both ends of the Dynamic
  // Type clamp. An overflow here is silent in a release build — Flutter paints
  // the stripes only in debug — so the only way it is ever caught is a sweep
  // like this one.
  group('no overflow', () {
    for (final Device device in kDevices) {
      for (final double scale in kTextScales) {
        testWidgets('${device.name} at ${scale}x, pause off', (
          WidgetTester tester,
        ) async {
          await pump(
            tester,
            profileGender: Gender.sister,
            device: device,
            textScale: scale,
          );
          expect(find.byType(CyclePauseRow), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('${device.name} at ${scale}x, pause on', (
          WidgetTester tester,
        ) async {
          await pump(
            tester,
            profileGender: Gender.sister,
            // Day 16: the panel with the "still paused?" line on it, which is
            // the tallest it ever gets.
            cycle: const Cycle(startedOn: '2026-08-31'),
            device: device,
            textScale: scale,
          );
          expect(find.byType(CyclePausedPanel), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('${device.name} at ${scale}x, start sheet', (
          WidgetTester tester,
        ) async {
          await pump(
            tester,
            profileGender: Gender.sister,
            device: device,
            textScale: scale,
          );
          await tap(tester, find.text('Pause prayers for these days'));

          expect(find.text('Pause prayers for these days?'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}

/// Stands in for Firestore under the real controller.
///
/// The delay matters: without an await that outlives the frame, a disposed
/// notifier would never get as far as its second assignment and the bug this
/// fake exists to catch would not reproduce.
class _FakeCycleRepo implements CycleRepository {
  _FakeCycleRepo({this.fails = false});

  final bool fails;
  int starts = 0;
  int ends = 0;

  @override
  Future<void> start({DateTime? now}) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (fails) throw const AppFailure('Firestore said no.');
    starts++;
  }

  @override
  Future<void> end() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (fails) throw const AppFailure('Firestore said no.');
    ends++;
  }

  @override
  Future<void> catchUp({required Cycle cycle, DateTime? now}) async {}
}

/// Counts the calls instead of writing to Firestore.
class _FakeCycleController extends CycleController {
  int starts = 0;
  int ends = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> start() async {
    starts++;
    return true;
  }

  @override
  Future<bool> end() async {
    ends++;
    return true;
  }
}
