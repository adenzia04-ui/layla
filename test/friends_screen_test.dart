import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/core/widgets/app_button.dart';
import 'package:noor/features/circles/application/circles_controller.dart';
import 'package:noor/features/circles/domain/circle.dart';
import 'package:noor/features/friends/application/friends_controller.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/friends/presentation/friends_screen.dart';
import 'package:noor/features/friends/presentation/widgets/add_friend_field.dart';
import 'package:noor/features/friends/presentation/widgets/friend_card.dart';
import 'package:noor/features/friends/presentation/widgets/friend_code_card.dart';

import 'test_fonts.dart';

/// The Friends screen with nothing behind it but fakes.
///
/// Every provider the screen reaches for is overridden, so no Firebase is
/// touched and no emulator is needed: what is under test is the screen's own
/// reading of the states it can be in — a list, an empty list, a guest, a code
/// still on its way and one that never arrived — and the one flow a person
/// drives by hand, typing a friend's code into the field.
void main() {
  setUpAll(loadNoorFonts);

  final String todayId = Fmt.dayId(DateTime.now());
  final DateTime since = DateTime(2026, 8, 20);

  /// Six middle dots: the placeholder that holds the plate's width while the
  /// code is being claimed.
  const String dots = '······';

  const Friend amira = Friend(uid: 'amira', name: 'Amira Khan', code: 'DEF345');
  const Friend yusuf = Friend(
    uid: 'yusuf',
    name: 'Yusuf Adeyemi',
    code: 'GHJ456',
  );

  Friend dated(Friend f) =>
      Friend(uid: f.uid, name: f.name, code: f.code, since: since);

  FriendProgress progressFor(
    Friend f, {
    int streak = 12,
    int longestStreak = 30,
    int totalPrayers = 1240,
    int totalTahajjud = 312,
    int todayCompleted = 3,
    String? todayDate,
    String? lastCompletedDate,
  }) => FriendProgress(
    uid: f.uid,
    name: f.name,
    code: f.code,
    streak: streak,
    longestStreak: longestStreak,
    totalPrayers: totalPrayers,
    totalTahajjud: totalTahajjud,
    todayCompleted: todayCompleted,
    todayDate: todayDate ?? todayId,
    lastCompletedDate: lastCompletedDate ?? todayId,
  );

  /// Pumps the screen with every one of its providers stubbed.
  ///
  /// [codeLoading] holds the code's future open, which is what a person sees
  /// for the second or two after a fresh sign-in; [codeFailed] is the claim
  /// that could not be made — no connection, or rules that refused it.
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Friend> friends = const <Friend>[],
    Map<String, FriendProgress?> progress = const <String, FriendProgress?>{},
    String? myCode = 'XYZ789',
    bool codeLoading = false,
    bool codeFailed = false,
    bool guest = false,
    _FakeFriendsActions? actions,
  }) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _FakeFriendsActions fake = actions ?? _FakeFriendsActions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          friendsGuestProvider.overrideWithValue(guest),
          friendsProvider.overrideWith(
            (Ref ref) => Stream<List<Friend>>.value(friends),
          ),
          friendProgressProvider.overrideWith(
            (Ref ref, String uid) =>
                Stream<FriendProgress?>.value(progress[uid]),
          ),
          myFriendCodeProvider.overrideWith((Ref ref) {
            if (codeLoading) return Completer<String?>().future;
            if (codeFailed) {
              return Future<String?>.error(
                Exception('no connection'),
                StackTrace.current,
              );
            }
            return Future<String?>.value(myCode);
          }),
          friendsActionsProvider.overrideWith(() => fake),
          // No circle has any code here: the field's second try, after a
          // code nobody owns as a friend code, comes back empty-handed too.
          circleActionsProvider.overrideWith(_FakeCircleActions.new),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: FriendsScreen(),
        ),
      ),
    );
    // One frame to subscribe, one for the streams and the future to land.
    await tester.pump();
    await tester.pump();
  }

  /// Lets a snackbar live out its four seconds, so no timer outlives the test.
  Future<void> settleSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  /// What the code field is showing.
  ///
  /// Read off the field itself rather than with `find.text`: its hint is
  /// "ABC-234" too, so a text finder cannot tell a typed code from an empty
  /// field waiting for one.
  String fieldText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('a signed-in person sees their code and their friends', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      myCode: 'ABC234',
      friends: <Friend>[dated(amira), dated(yusuf)],
      progress: <String, FriendProgress?>{
        amira.uid: progressFor(dated(amira)),
        yusuf.uid: progressFor(
          dated(yusuf),
          streak: 4,
          longestStreak: 9,
          totalPrayers: 220,
          totalTahajjud: 6,
          todayCompleted: 0,
        ),
      },
    );

    // The code is shown the way it is read aloud, never as six bare letters.
    // Scoped to the card: the add-a-friend field hints with a code too.
    expect(
      find.descendant(
        of: find.byType(FriendCodeCard),
        matching: find.text('ABC-234'),
      ),
      findsOneWidget,
    );
    expect(find.text('ABC234'), findsNothing);

    expect(find.text('Amira Khan'), findsOneWidget);
    expect(find.text('Yusuf Adeyemi'), findsOneWidget);
    expect(find.byType(FriendCard), findsNWidgets(2));
    expect(find.text('Friends · 2'.toUpperCase()), findsOneWidget);

    // Today, the chain, and the long run — the three things a friend looks at.
    expect(find.text('3 of 5 today'), findsOneWidget);
    expect(find.text('0 of 5 today'), findsOneWidget);
    expect(find.text('12 days'), findsOneWidget);
    expect(find.text('4 days'), findsOneWidget);
    expect(
      find.text('1,240 prayers · 312 Tahajjud nights'),
      findsOneWidget,
      reason: 'totals are grouped, and both sit on one line',
    );
    expect(find.text('220 prayers · 6 Tahajjud nights'), findsOneWidget);
  });

  testWidgets('a lapsed streak shows no flame and no day count', (
    WidgetTester tester,
  ) async {
    final String longAgo = Fmt.dayId(
      DateTime.now().subtract(const Duration(days: 9)),
    );
    await pumpScreen(
      tester,
      friends: <Friend>[dated(amira)],
      progress: <String, FriendProgress?>{
        amira.uid: progressFor(
          dated(amira),
          streak: 12,
          lastCompletedDate: longAgo,
          todayDate: longAgo,
        ),
      },
    );

    expect(find.text('12 days'), findsNothing);
    expect(
      find.text('0 of 5 today'),
      findsOneWidget,
      reason: 'a tally stamped with an older day is not today\'s',
    );
  });

  testWidgets('nobody added yet says so, and shows no cards', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('No friends yet'), findsOneWidget);
    expect(find.byType(FriendCard), findsNothing);
    // The two things that make a friendship are still on the screen.
    expect(find.byType(FriendCodeCard), findsOneWidget);
    expect(find.byType(AddFriendField), findsOneWidget);
  });

  testWidgets('a guest is offered an account instead of a code', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, guest: true);

    expect(find.text('Friends need an account'), findsOneWidget);
    expect(find.widgetWithText(PrimaryButton, 'Sign in'), findsOneWidget);
    expect(
      find.byType(FriendCodeCard),
      findsNothing,
      reason: 'a guest has no code to show, and the rules refuse them one',
    );
    expect(find.byType(AddFriendField), findsNothing);
    expect(find.byType(FriendCard), findsNothing);
  });

  testWidgets('while the code is claimed the plate holds its width', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, codeLoading: true);

    expect(find.text(dots), findsOneWidget);
    // Nothing to copy or share yet, so neither offers to.
    for (final String label in <String>['Copy', 'Share']) {
      final OutlinedButton button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, label),
      );
      expect(button.onPressed, isNull, reason: '$label is live with no code');
    }
  });

  testWidgets('a code that could not be claimed offers another go', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester, codeFailed: true);

    expect(find.text(dots), findsOneWidget);
    expect(
      find.text('Your code could not be loaded. Tap to try again.'),
      findsOneWidget,
      reason: 'a card that only ever shows dots says nothing about why',
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Copy'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a friend who has never published reads as exactly that', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      friends: <Friend>[dated(amira)],
      progress: <String, FriendProgress?>{amira.uid: null},
    );

    expect(find.text('Amira Khan'), findsOneWidget);
    expect(find.text('No progress shared yet'), findsOneWidget);
    expect(find.textContaining('of 5 today'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the code field', () {
    testWidgets('shapes what is typed into a code', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'abc234');
      await tester.pump();
      expect(
        fieldText(tester),
        'ABC-234',
        reason: 'lowercase is lifted and the hyphen put in',
      );

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(
        fieldText(tester),
        'ABC',
        reason: 'a code still being typed carries no trailing hyphen',
      );

      // A paste arrives whole, hyphen, spaces, look-alikes and all.
      await tester.enterText(find.byType(TextField), '  ab c-2 34xyz');
      await tester.pump();
      expect(fieldText(tester), 'ABC-234', reason: 'cut at six');
    });

    testWidgets('a valid code is handed over once, and the field clears', (
      WidgetTester tester,
    ) async {
      final _FakeFriendsActions actions = _FakeFriendsActions();
      await pumpScreen(tester, actions: actions);

      await tester.enterText(find.byType(TextField), 'abc-234');
      await tester.pump();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();

      expect(actions.added, <String>['ABC234'], reason: 'once, normalised');
      expect(
        fieldText(tester),
        isEmpty,
        reason: 'the field clears so the next code can be typed',
      );
      expect(find.textContaining('are now friends'), findsOneWidget);
      await settleSnackbar(tester);
    });

    testWidgets('a half-typed code never reaches Firestore', (
      WidgetTester tester,
    ) async {
      final _FakeFriendsActions actions = _FakeFriendsActions();
      await pumpScreen(tester, actions: actions);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();

      expect(actions.added, isEmpty);
      expect(find.text('A code has six letters and numbers.'), findsOneWidget);
    });

    // One test per reason rather than one loop through them: when this fails
    // the name of the failing test is the answer, and a fresh tree per error
    // is the only way to be sure the sentence on screen is this error's and
    // not the one before it.
    for (final FriendAddError error in FriendAddError.values) {
      testWidgets('${error.name} is put in its own words', (
        WidgetTester tester,
      ) async {
        await pumpScreen(tester, actions: _FakeFriendsActions(fail: error));

        await tester.enterText(find.byType(TextField), 'abc234');
        await tester.pump();
        await tester.tap(find.text('Add friend'));
        await tester.pumpAndSettle();

        expect(
          find.text(friendAddSentence(error)),
          findsOneWidget,
          reason: 'no sentence on screen for $error',
        );
        // The code stays in the field: the person may only have mistyped it.
        expect(fieldText(tester), 'ABC-234', reason: '$error');
        await settleSnackbar(tester);
      });
    }

    test('no two reasons share a sentence', () {
      final Set<String> sentences = FriendAddError.values
          .map(friendAddSentence)
          .toSet();
      expect(
        sentences.length,
        FriendAddError.values.length,
        reason: 'a repeated sentence leaves someone with the wrong next step',
      );
      expect(sentences.every((String s) => s.trim().isNotEmpty), isTrue);
    });

    testWidgets('typing again clears the sentence', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        actions: _FakeFriendsActions(fail: FriendAddError.notFound),
      );

      await tester.enterText(find.byType(TextField), 'abc234');
      await tester.pump();
      await tester.tap(find.text('Add friend'));
      await tester.pumpAndSettle();
      expect(find.text('That code does not belong to anyone.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'abc235');
      await tester.pump();
      expect(find.text('That code does not belong to anyone.'), findsNothing);
    });
  });

  testWidgets('a tapped friend opens on their numbers and their code', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      myCode: 'ABC234',
      friends: <Friend>[dated(amira)],
      progress: <String, FriendProgress?>{amira.uid: progressFor(dated(amira))},
    );

    // The card sits under the you-card and the inbox strip, below the fold.
    await tester.ensureVisible(find.byType(FriendCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FriendCard));
    await tester.pumpAndSettle();

    // Their code, which the card does not show — so this is the sheet.
    expect(find.text('DEF-345'), findsOneWidget);
    expect(find.text('Amira Khan'), findsNWidgets(2));
    expect(find.text('Friends since 20 Aug'), findsOneWidget);

    // The three counters, each on its own, and the streak as it stands today.
    expect(find.text('12'), findsOneWidget);
    expect(find.text('day streak'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('prayers'), findsOneWidget);
    expect(find.text('312'), findsOneWidget);
    expect(find.text('Tahajjud nights'), findsOneWidget);
    expect(find.textContaining('Longest streak 30 days'), findsOneWidget);
    expect(find.text('Remove friend'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A stand-in for [FriendsActions] that records what it was asked to do.
///
/// It keeps the real controller's manners: a refusal is left in `state` rather
/// than thrown, which is the path the field actually reads.
class _FakeFriendsActions extends FriendsActions {
  _FakeFriendsActions({this.fail});

  final FriendAddError? fail;

  final List<String> added = <String>[];
  final List<String> removed = <String>[];

  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  @override
  Future<Friend?> add(String code) async {
    added.add(code);
    state = const AsyncValue<void>.loading();
    final FriendAddError? error = fail;
    if (error != null) {
      state = AsyncValue<void>.error(
        FriendAddException(error),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncValue<void>.data(null);
    return Friend(uid: 'added', name: 'Amira Khan', code: code);
  }

  @override
  Future<void> remove(String uid) async {
    removed.add(uid);
    state = const AsyncValue<void>.data(null);
  }
}

/// A stand-in for [CircleActions] under which no code opens a circle.
///
/// It keeps the real controller's manners: the refusal is left in `state`
/// rather than thrown, which is the path the field reads.
class _FakeCircleActions extends CircleActions {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  @override
  Future<Circle?> join(String code) async {
    state = const AsyncValue<void>.loading();
    state = AsyncValue<void>.error(
      const CircleJoinException(CircleJoinError.notFound),
      StackTrace.current,
    );
    return null;
  }
}
