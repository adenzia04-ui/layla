import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/core/widgets/avatar_circle.dart';
import 'package:noor/features/auth/data/auth_repository.dart';
import 'package:noor/features/auth/domain/app_user.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/profile/domain/avatar.dart';
import 'package:noor/features/profile/presentation/profile_screen.dart';
import 'package:noor/features/streaks/application/streak_controller.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';

import 'test_fonts.dart';

/// The profile picture, end to end, with no Firebase anywhere near it.
///
/// Two things here are worth more than they look. The first is that nothing in
/// this path may throw: the string is a base64 JPEG copied off another
/// person's Firestore document, so a friend's truncated or half-written
/// picture arrives on YOUR phone, inside a `build`, and the only acceptable
/// outcome is their initials. The second is the ceiling — `Avatar.maxChars`,
/// the same number firestore.rules enforces. A write past it is refused
/// silently, so the client has to agree with the rules exactly or a person is
/// left looking at an unchanged avatar with nothing to explain it.
///
/// The ceilings themselves are asserted in `avatar_crop_test.dart`, which
/// owns the two sizes a picture is stored at.
void main() {
  setUpAll(loadNoorFonts);

  // Decoded pictures are memoised for the life of the isolate, so each test
  // has to start from nothing or it could be reading the one before it.
  setUp(Avatar.clearCache);

  /// A real 1x1 PNG. Small enough to sit in a test, and genuinely decodable —
  /// which matters, because valid base64 that is not an image takes a
  /// different path through AvatarCircle.
  const String onePixelPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
      'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  group('Avatar.isUsable', () {
    test('null is not a picture', () {
      expect(Avatar.isUsable(null), isFalse);
    });

    test('an empty string is not a picture', () {
      expect(Avatar.isUsable(''), isFalse);
    });

    test('an ordinary string is', () {
      expect(Avatar.isUsable(onePixelPng), isTrue);
    });

    test('exactly maxChars is still usable — the ceiling is inclusive', () {
      expect(Avatar.isUsable('a' * Avatar.maxChars), isTrue);
    });

    test('one character past the ceiling is not', () {
      expect(
        Avatar.isUsable('a' * (Avatar.maxChars + 1)),
        isFalse,
        reason:
            'the rules refuse this, and a refused write is silent — the '
            'client has to draw the same line they do',
      );
    });
  });

  group('Avatar.provider', () {
    test('hands back an image for real base64', () {
      final ImageProvider? image = Avatar.provider(onePixelPng);
      expect(image, isA<ResizeImage>());
      expect((image! as ResizeImage).imageProvider, isA<MemoryImage>());
    });

    test('the decode is bounded, not just the string', () {
      // Avatar.maxChars bounds the base64; it cannot bound the pixels, because
      // JPEG is compressed. A friend's progress document is written by their
      // phone, so 48 KB declaring 12000x12000 is a decode that would take this
      // phone down — and neither `Image.width` nor `errorBuilder` can stop a
      // native allocation. ResizeImage makes the codec sample-decode instead.
      final ResizeImage image = Avatar.provider(onePixelPng)! as ResizeImage;

      expect(image.width, Avatar.maxDecodeSide);
      expect(image.height, Avatar.maxDecodeSide);
      expect(image.policy, ResizeImagePolicy.fit);
      expect(
        image.allowUpscaling,
        isFalse,
        reason: 'a 64-pixel picture must not be blown up to draw it at 44',
      );
    });

    test('the same string hands back the same instance', () {
      expect(
        identical(Avatar.provider(onePixelPng), Avatar.provider(onePixelPng)),
        isTrue,
        reason:
            'this is called from build; re-decoding 48KB on every frame of a '
            'scroll is the whole reason the memo exists',
      );
    });

    test('null and empty have nothing to draw', () {
      expect(Avatar.provider(null), isNull);
      expect(Avatar.provider(''), isNull);
    });

    test('an oversize string is refused rather than half-drawn', () {
      expect(Avatar.provider('a' * (Avatar.maxChars + 1)), isNull);
    });

    test('malformed base64 is a null, never a throw', () {
      expect(
        Avatar.provider('not!base64'),
        isNull,
        reason:
            'base64Decode throws on this, and it is reached from a build '
            'method with a value written by someone else',
      );
    });
  });

  group('AvatarCircle', () {
    Future<void> pump(WidgetTester tester, {String? photo}) =>
        tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              body: Center(
                child: AvatarCircle(initials: 'AZ', photo: photo),
              ),
            ),
          ),
        );

    testWidgets('draws the picture when there is one', (
      WidgetTester tester,
    ) async {
      await pump(tester, photo: onePixelPng);

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('AZ'), findsNothing);
    });

    testWidgets('falls back to initials with no picture', (
      WidgetTester tester,
    ) async {
      await pump(tester);

      expect(find.text('AZ'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('malformed base64 draws initials and does not throw', (
      WidgetTester tester,
    ) async {
      await pump(tester, photo: 'not!base64');

      expect(find.text('AZ'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: "a friend's bad picture must not take down your friends list",
      );
    });
  });

  group('FriendProgress carries the picture', () {
    const FriendProgress sent = FriendProgress(
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
      photo: onePixelPng,
    );

    test('round trips through the document', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{
          ...sent.toMap(),
          'updatedAt': Timestamp.fromDate(DateTime(2026, 9, 14, 21, 30)),
        }),
      );

      expect(back.photo, onePixelPng);
      expect(back.name, sent.name, reason: 'the rest of the map still works');
    });

    test('the key is written even when there is no picture', () {
      expect(
        const FriendProgress(
          uid: 'them',
          name: 'Yusuf Adeyemi',
          code: 'DEF345',
        ).toMap(),
        containsPair('photo', isNull),
        reason:
            'the publisher compares two of these maps, so a key that comes '
            'and goes would hide a picture being removed',
      );
    });

    test('a document with no photo field reads as no picture', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{'name': 'Yusuf Adeyemi'}),
      );

      expect(back.photo, isNull);
    });

    test('a photo field that is not a string does not throw', () {
      final FriendProgress back = FriendProgress.fromDoc(
        _FakeDoc('them', <String, Object?>{'photo': 42}),
      );

      expect(back.photo, isNull);
    });
  });

  group('the profile avatar', () {
    Future<void> pumpProfile(WidgetTester tester, {String? photo}) async {
      final AppUser user = AppUser(
        uid: 'me',
        displayName: 'Aden Zia',
        email: 'aden@example.com',
        photo: photo,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            profileGuestProvider.overrideWithValue(false),
            appUserProvider.overrideWith(
              (Ref ref) => Stream<AppUser?>.value(user),
            ),
            streakHistoryProvider.overrideWith(
              (Ref ref) => Stream<StreakHistory>.value(
                const StreakHistory(year: 2026, days: <String, PrayerDay>{}),
              ),
            ),
          ],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('opens the picture sheet when tapped', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);

      await tester.tap(find.byType(AvatarCircle));
      await tester.pumpAndSettle();

      expect(find.text('Choose a photo'), findsOneWidget);
      expect(
        find.text('Remove photo'),
        findsNothing,
        reason: 'there is nothing to remove until a picture is set',
      );
    });

    testWidgets('offers to remove the picture once there is one', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester, photo: onePixelPng);

      await tester.tap(find.byType(AvatarCircle));
      await tester.pumpAndSettle();

      expect(find.text('Choose a photo'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
    });

    testWidgets('the camera badge opens the sheet as well as the circle', (
      WidgetTester tester,
    ) async {
      await pumpProfile(tester);

      // The badge hangs off the rim — its centre is outside the circle — and
      // the circle's ink well is clipped to a CircleBorder, so before the
      // outer detector was added this tap reached nothing at all. It is the
      // one thing on the screen that says the avatar can be changed, so it is
      // also the thing people aim at.
      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Choose a photo'), findsOneWidget);
    });
  });

  group('initials at large text sizes', () {
    testWidgets('a wide pair stays inside the ring at the 1.3 clamp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          // The top of the app's clamp, where a fixed-size circle and growing
          // letters are furthest apart.
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const Scaffold(
              body: Center(child: AvatarCircle(initials: 'WM')),
            ),
          ),
        ),
      );

      // getRect, not getSize: inside a FittedBox the text's own size is its
      // unscaled one, and what matters is the rectangle actually painted.
      final Rect text = tester.getRect(find.text('WM'));
      final Rect circle = tester.getRect(find.byType(AvatarCircle));
      // 1.5pt of gold on each side, so the letters have to stop short of it.
      expect(
        text.width,
        lessThanOrEqualTo(circle.width - 3),
        reason: 'wide initials must not run under the ring at large type',
      );
    });
  });
}

// ignore: subtype_of_sealed_class
/// The one thing `fromDoc` actually reads: an id and a map.
///
/// The same stand-in friends_progress_test.dart uses, and for the same reason:
/// a real `DocumentSnapshot` cannot be built without Firestore, and testing a
/// hand-written copy of `fromDoc` would check a reimplementation rather than
/// the function friends' phones actually run.
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
