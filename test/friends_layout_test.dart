import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/friends/application/friends_controller.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/friends/presentation/friends_screen.dart';
import 'package:noor/features/friends/presentation/widgets/friend_card.dart';

import 'device_sizes.dart';
import 'test_fonts.dart';

/// Friends, on every iPhone Layla Pro lands on, at both ends of the Dynamic
/// Type clamp.
///
/// The screen is the app's widest content per line: an avatar, a name, a
/// flame and a day count on one row; five dots and a tally on the next; two
/// six-figure totals on the one after. The friend sheet then puts three of
/// those totals side by side in thirds of the screen. A RenderFlex that runs
/// out of room reports an overflow through FlutterError, which `takeException`
/// turns into a failure — and that matters because **release builds do not
/// draw the yellow stripes**: on a real small phone the overflow is silent and
/// simply clips, so a friend's cut-off streak reaches someone who never
/// mentions it.
void main() {
  setUpAll(loadNoorFonts);

  final String todayId = Fmt.dayId(DateTime.now());

  // The worst honest case, not a tidy one. A name of three long words, totals
  // in six figures and a chain of a full year: each is reachable, and each is
  // wider than the value a screenshot is usually taken with.
  final Friend crowded = Friend(
    uid: 'kindi',
    name: 'Muhammad Abdurrahman Al-Kindi',
    code: 'DEF345',
    since: DateTime(2024, 9, 14),
  );
  final Friend second = Friend(
    uid: 'yusuf',
    name: 'Yusuf Adeyemi',
    code: 'GHJ456',
    since: DateTime(2026, 8, 20),
  );

  FriendProgress heavy(Friend f) => FriendProgress(
    uid: f.uid,
    name: f.name,
    code: f.code,
    streak: 365,
    longestStreak: 365,
    totalPrayers: 123456,
    totalTahajjud: 3200,
    todayCompleted: 5,
    todayDate: todayId,
    lastCompletedDate: todayId,
    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Device device,
    required double scale,
    List<Friend> friends = const <Friend>[],
    bool guest = false,
    String? myCode = 'ABC234',
  }) async {
    useDevice(tester, device);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          friendsGuestProvider.overrideWithValue(guest),
          friendsProvider.overrideWith(
            (Ref ref) => Stream<List<Friend>>.value(friends),
          ),
          friendProgressProvider.overrideWith(
            (Ref ref, String uid) => Stream<FriendProgress?>.value(
              heavy(friends.firstWhere((Friend f) => f.uid == uid)),
            ),
          ),
          myFriendCodeProvider.overrideWith(
            (Ref ref) => Future<String?>.value(myCode),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // The device goes on above the Navigator rather than around the
          // screen, so the modal sheet — which lives in the root overlay —
          // is laid out on the same phone at the same text scale.
          builder: (BuildContext context, Widget? child) =>
              asDevice(device: device, textScale: scale, child: child!),
          home: const FriendsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Renders [what] on every phone at both ends of the text-scale clamp.
  ///
  /// One test per device: when this fails the name of the failing test is the
  /// answer — you learn it is the SE at 1.3x without reading a stack trace.
  void matrix(
    String what, {
    List<Friend> friends = const <Friend>[],
    bool guest = false,
    String? myCode = 'ABC234',
  }) {
    for (final Device device in kDevices) {
      for (final double scale in kTextScales) {
        testWidgets('$what fits $device at ${scale}x', (
          WidgetTester tester,
        ) async {
          await pumpScreen(
            tester,
            device: device,
            scale: scale,
            friends: friends,
            guest: guest,
            myCode: myCode,
          );

          expect(
            tester.takeException(),
            isNull,
            reason:
                '$what overflows on $device at ${scale}x text. On a real '
                'phone this clips silently — no stripes in release.',
          );
        });
      }
    }
  }

  matrix('a crowded friends list', friends: <Friend>[crowded, second]);
  matrix('the empty friends list');
  matrix('the guest card', guest: true);
  // The plate is the one place a code is drawn at display size with six
  // points of letter spacing, and the dots stand in at the same width.
  matrix('a friends list with no code yet', myCode: null);

  /// The sheet, on the phone that has the least room for it.
  ///
  /// Its three stats sit in thirds of the screen — on an SE that is 111 points
  /// each, and "Tahajjud nights" under a six-figure total has to wrap inside
  /// them rather than be cut.
  for (final double scale in kTextScales) {
    testWidgets('the friend sheet fits ${kDevices.first} at ${scale}x', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        device: kDevices.first,
        scale: scale,
        friends: <Friend>[crowded, second],
      );

      // The list sits below the code and the field; on a 667pt screen the
      // first card is off the bottom until the page is scrolled to it.
      await tester.ensureVisible(find.byType(FriendCard).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FriendCard).first);
      await tester.pumpAndSettle();

      expect(find.text('Remove friend'), findsOneWidget, reason: 'not opened');
      expect(
        tester.takeException(),
        isNull,
        reason:
            'the friend sheet overflows on ${kDevices.first} at ${scale}x '
            'text — and in release that is a clip, not a stripe.',
      );
    });
  }
}
