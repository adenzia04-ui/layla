import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:noor/core/routing/routes.dart';
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/circles/application/circles_controller.dart';
import 'package:noor/features/circles/domain/circle.dart';
import 'package:noor/features/circles/presentation/circle_screen.dart';
import 'package:noor/features/friends/application/friends_controller.dart';
import 'package:noor/features/friends/application/invite.dart';
import 'package:noor/features/friends/domain/friend.dart';
import 'package:noor/features/friends/domain/inbox_item.dart';
import 'package:noor/features/friends/domain/jumuah.dart';
import 'package:noor/features/friends/presentation/friends_screen.dart';
import 'package:noor/features/friends/presentation/widgets/friend_card.dart';
import 'package:noor/features/friends/presentation/widgets/you_card.dart';
import 'package:noor/features/mood/application/mood_store.dart';
import 'package:noor/features/mood/domain/mood_comfort.dart';

import 'device_sizes.dart';
import 'test_fonts.dart';

/// Friends, round two, with nothing behind it but fakes.
///
/// What is under test is the screen's reading of the new states — cheers on
/// your own card, a friend gone quiet, a fresh milestone, a code that turns
/// out to be a circle's — and that the whole of it, fully populated with the
/// longest honest names, fits every iPhone at both ends of the text clamp.
void main() {
  setUpAll(loadNoorFonts);

  final String todayId = Fmt.dayId(DateTime.now());
  final DateTime since = DateTime(2026, 8, 20);
  final DateTime now = DateTime.now();

  Friend friend(String uid, String name, String code) =>
      Friend(uid: uid, name: name, code: code, since: since);

  final Friend amira = friend('amira', 'Amira Khan', 'DEF345');
  final Friend yusuf = friend('yusuf', 'Yusuf Adeyemi', 'GHJ456');
  final Friend crowded = friend(
    'kindi',
    'Muhammad Abdurrahman Al-Kindi',
    'KLM567',
  );

  FriendProgress progressFor(
    Friend f, {
    int streak = 12,
    int longestStreak = 30,
    int totalPrayers = 1240,
    int totalTahajjud = 312,
    int todayCompleted = 3,
    bool quiet = false,
    Milestone? milestone,
    RamadanShare? ramadan,
  }) => FriendProgress(
    uid: f.uid,
    name: f.name,
    code: f.code,
    streak: streak,
    longestStreak: longestStreak,
    totalPrayers: totalPrayers,
    totalTahajjud: totalTahajjud,
    todayCompleted: todayCompleted,
    todayDate: todayId,
    lastCompletedDate: todayId,
    updatedAt: now.subtract(const Duration(hours: 2)),
    quiet: quiet,
    milestone: milestone,
    ramadan: ramadan,
  );

  final Milestone freshHundred = Milestone(
    key: MilestoneKey.streak100,
    at: now.subtract(const Duration(days: 1)),
  );

  Circle circleNamed(String id, String name, {List<String>? members}) => Circle(
    id: id,
    name: name,
    goal: CircleGoal.fajr,
    startsOn: Fmt.dayId(now.subtract(const Duration(days: 11))),
    days: 40,
    code: 'QRS789',
    createdBy: 'me',
    members: members ?? <String>['me', 'amira', 'yusuf'],
    createdAt: now.subtract(const Duration(days: 11)),
  );

  /// Every provider the screen and its sheets reach for, stubbed.
  List<Override> overrides({
    List<Friend> friends = const <Friend>[],
    Map<String, FriendProgress?> progress = const <String, FriendProgress?>{},
    FriendProgress? mine,
    bool quiet = false,
    int cheers = 0,
    Milestone? myMilestone,
    bool friday = false,
    Map<String, String> masjids = const <String, String>{},
    Map<String, int> together = const <String, int>{},
    bool ramadan = false,
    List<InboxItem> inbox = const <InboxItem>[],
    List<Circle> circles = const <Circle>[],
    Map<String, List<CircleProgress>> circleProgress =
        const <String, List<CircleProgress>>{},
    String? pendingInvite,
    Set<String> saved = const <String>{},
    _FakeFriendsActions? actions,
    _FakeCircleActions? circleActions,
  }) => <Override>[
    friendsGuestProvider.overrideWithValue(false),
    friendsUidProvider.overrideWithValue('me'),
    friendsProvider.overrideWith(
      (Ref ref) => Stream<List<Friend>>.value(friends),
    ),
    friendProgressProvider.overrideWith(
      (Ref ref, String uid) => Stream<FriendProgress?>.value(progress[uid]),
    ),
    myFriendCodeProvider.overrideWith(
      (Ref ref) => Future<String?>.value('XYZ789'),
    ),
    myProgressProvider.overrideWithValue(mine),
    quietProvider.overrideWithValue(quiet),
    cheersReceivedProvider.overrideWith((Ref ref) => Stream<int>.value(cheers)),
    myMilestoneProvider.overrideWithValue(myMilestone),
    isFridayProvider.overrideWithValue(friday),
    jumuahProvider.overrideWith(
      (Ref ref, String uid) => Stream<Jumuah?>.value(
        masjids[uid] == null
            ? null
            : Jumuah(masjid: masjids[uid]!, date: Jumuah.comingFridayId(now)),
      ),
    ),
    togetherProvider.overrideWith((Ref ref, String uid) => together[uid]),
    isRamadanProvider.overrideWithValue(ramadan),
    inboxProvider.overrideWith(
      (Ref ref) => Stream<List<InboxItem>>.value(inbox),
    ),
    circlesProvider.overrideWith(
      (Ref ref) => Stream<List<Circle>>.value(circles),
    ),
    circleProvider.overrideWith(
      (Ref ref, String id) => Stream<Circle?>.value(
        circles.where((Circle c) => c.id == id).firstOrNull,
      ),
    ),
    circleMembersProgressProvider.overrideWith(
      (Ref ref, String id) => Stream<List<CircleProgress>>.value(
        circleProgress[id] ?? const <CircleProgress>[],
      ),
    ),
    pendingInviteProvider.overrideWith((Ref ref) => pendingInvite),
    savedComfortsProvider.overrideWith(() => _FakeSaved(saved)),
    friendsActionsProvider.overrideWith(() => actions ?? _FakeFriendsActions()),
    circleActionsProvider.overrideWith(
      () => circleActions ?? _FakeCircleActions(),
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Override> overrides,
    Widget home = const FriendsScreen(),
    Device? device,
    double scale = 1.0,
  }) async {
    if (device == null) {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    } else {
      useDevice(tester, device);
    }
    // A real router, as the app has: joining a circle pushes its screen.
    final GoRouter router = GoRouter(
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '${Routes.friends}/circles/:id',
          builder: (_, GoRouterState state) =>
              CircleScreen(circleId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: router,
          builder: device == null
              ? null
              : (BuildContext context, Widget? child) =>
                    asDevice(device: device, textScale: scale, child: child!),
        ),
      ),
    );
    // One frame to subscribe, one for the streams and the future to land.
    await tester.pump();
    await tester.pump();
  }

  /// Every piece of text inside [finder].
  List<String> textsIn(WidgetTester tester, Finder finder) => tester
      .widgetList<Text>(
        find.descendant(of: finder, matching: find.byType(Text)),
      )
      .map((Text t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .toList();

  group('the you-card', () {
    testWidgets('says nothing about MashaAllah when nobody has said it', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        overrides: overrides(mine: progressFor(friend('me', 'Me', 'XYZ789'))),
      );
      expect(find.byType(YouCard), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.textContaining('said MashaAllah'), findsNothing);
      expect(find.text('12 days'), findsOneWidget);
      expect(find.text('3 of 5 today'), findsOneWidget);
      expect(find.text('Quiet for now'), findsOneWidget);
    });

    testWidgets('counts the friends who said it, once there are any', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        overrides: overrides(
          mine: progressFor(friend('me', 'Me', 'XYZ789')),
          cheers: 3,
          myMilestone: freshHundred,
        ),
      );
      expect(find.text('3 friends said MashaAllah'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(YouCard),
          matching: find.text('100 days'),
        ),
        findsOneWidget,
        reason: 'your own fresh milestone is shown beside the cheers',
      );
    });

    testWidgets('one friend is singular', (WidgetTester tester) async {
      await pumpScreen(tester, overrides: overrides(cheers: 1));
      expect(find.text('1 friend said MashaAllah'), findsOneWidget);
    });

    testWidgets('the Quiet switch hands its value to the controller', (
      WidgetTester tester,
    ) async {
      final _FakeFriendsActions actions = _FakeFriendsActions();
      await pumpScreen(tester, overrides: overrides(actions: actions));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(actions.quiet, <bool>[true]);
    });
  });

  testWidgets('a quiet friend shows no digits anywhere on its card', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: overrides(
        friends: <Friend>[amira],
        friday: true,
        ramadan: true,
        masjids: <String, String>{amira.uid: 'Masjid Al-Falah'},
        together: <String, int>{amira.uid: 240},
        progress: <String, FriendProgress?>{
          amira.uid: progressFor(
            amira,
            quiet: true,
            streak: 365,
            totalPrayers: 123456,
            totalTahajjud: 3200,
            todayCompleted: 5,
            milestone: freshHundred,
            ramadan: RamadanShare(
              fasts: 12,
              fastingToday: true,
              taraweeh: true,
              date: todayId,
            ),
          ),
        },
      ),
    );

    final Finder card = find.byType(FriendCard);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Quiet for now')),
      findsOneWidget,
    );
    final List<String> texts = textsIn(tester, card);
    for (final String text in texts) {
      expect(
        text.contains(RegExp(r'\d')),
        isFalse,
        reason: '"$text" carries a number on a quiet friend\'s card',
      );
    }
    expect(find.text('MashaAllah'), findsNothing);
    expect(find.textContaining('Updated'), findsNothing);
    expect(
      find.text('Masjid Al-Falah this Friday'),
      findsOneWidget,
      reason: 'the masjid is something they chose to say; it is not a number',
    );
  });

  testWidgets('the MashaAllah button calls cheer once and then disables', (
    WidgetTester tester,
  ) async {
    final _FakeFriendsActions actions = _FakeFriendsActions();
    await pumpScreen(
      tester,
      overrides: overrides(
        friends: <Friend>[amira],
        progress: <String, FriendProgress?>{
          amira.uid: progressFor(amira, milestone: freshHundred),
        },
        actions: actions,
      ),
    );

    final Finder button = find.widgetWithText(OutlinedButton, 'MashaAllah');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button, findsOneWidget);
    expect(find.text('100 days'), findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(actions.cheers, <(String, MilestoneKey)>[
      ('amira', MilestoneKey.streak100),
    ]);

    final Finder said = find.widgetWithText(OutlinedButton, 'MashaAllah said');
    expect(said, findsOneWidget);
    expect(tester.widget<OutlinedButton>(said).onPressed, isNull);
    await tester.tap(said, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(actions.cheers.length, 1, reason: 'said once, and once only');
  });

  testWidgets('the add field tries join(code) when addByCode throws notFound', (
    WidgetTester tester,
  ) async {
    final _FakeCircleActions circleActions = _FakeCircleActions();
    await pumpScreen(
      tester,
      overrides: overrides(
        actions: _FakeFriendsActions(fail: FriendAddError.notFound),
        circleActions: circleActions,
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'qrs-789');
    await tester.pump();
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();

    expect(circleActions.joined, <String>['QRS789']);
    expect(find.textContaining('You are in'), findsOneWidget);
    expect(
      find.byType(CircleScreen),
      findsOneWidget,
      reason: 'a joined circle opens on its own screen',
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a code no circle has either keeps the friend-code sentence', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      overrides: overrides(
        actions: _FakeFriendsActions(fail: FriendAddError.notFound),
        circleActions: _FakeCircleActions(fail: true),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'qrs-789');
    await tester.pump();
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    expect(find.text('That code does not belong to anyone.'), findsOneWidget);
  });

  group('everything populated fits', () {
    final List<Friend> friends = <Friend>[crowded, amira, yusuf];
    final List<InboxItem> inbox = <InboxItem>[
      InboxItem(
        id: 'i1',
        type: InboxType.verse,
        fromUid: 'kindi',
        fromName: 'Muhammad Abdurrahman Al-Kindi',
        at: now,
        comfortId: MoodComfort.forMood(Mood.anxious).first.id,
      ),
      InboxItem(
        id: 'i2',
        type: InboxType.eid,
        fromUid: 'amira',
        fromName: 'Amira Khan',
        at: now,
      ),
      InboxItem(
        id: 'i3',
        type: InboxType.circle,
        fromUid: 'yusuf',
        fromName: 'Yusuf Adeyemi',
        at: now,
        circleId: 'c1',
        circleCode: 'QRS789',
      ),
    ];
    final List<Circle> circles = <Circle>[
      circleNamed('c1', 'Fajr on time with the whole extended family'),
      circleNamed('c2', 'Tahajjud', members: <String>['me']),
    ];
    final Map<String, FriendProgress?> progress = <String, FriendProgress?>{
      crowded.uid: progressFor(
        crowded,
        streak: 365,
        totalPrayers: 123456,
        totalTahajjud: 3200,
        todayCompleted: 5,
        milestone: Milestone(
          key: MilestoneKey.tahajjud100,
          at: now.subtract(const Duration(days: 2)),
        ),
        ramadan: RamadanShare(
          fasts: 30,
          fastingToday: true,
          taraweeh: true,
          date: todayId,
        ),
      ),
      amira.uid: progressFor(amira, quiet: true),
      yusuf.uid: progressFor(yusuf, milestone: freshHundred),
    };
    final Map<String, String> masjids = <String, String>{
      crowded.uid: 'Masjid Abdurrahman ibn Awf Islamic Centre',
      'me': 'Masjid Al-Falah',
    };
    final Map<String, int> together = <String, int>{
      crowded.uid: 123456,
      yusuf.uid: 1,
    };

    List<Override> everything() => overrides(
      friends: friends,
      progress: progress,
      mine: progressFor(
        friend('me', 'Me', 'XYZ789'),
        streak: 1000,
        totalPrayers: 200000,
        totalTahajjud: 40000,
      ),
      cheers: 19,
      myMilestone: Milestone(
        key: MilestoneKey.prayers5000,
        at: now.subtract(const Duration(days: 3)),
      ),
      friday: true,
      masjids: masjids,
      together: together,
      ramadan: true,
      inbox: inbox,
      circles: circles,
      circleProgress: <String, List<CircleProgress>>{
        'c1': <CircleProgress>[
          CircleProgress(uid: 'me', kept: 12, updatedAt: now),
          CircleProgress(uid: 'amira', kept: 9, updatedAt: now),
          CircleProgress(uid: 'yusuf', kept: 3, updatedAt: now),
        ],
      },
      pendingInvite: 'DEF345',
    );

    for (final Device device in kDevices) {
      for (final double scale in kTextScales) {
        testWidgets('the Friends screen on $device at ${scale}x', (
          WidgetTester tester,
        ) async {
          await pumpScreen(
            tester,
            overrides: everything(),
            device: device,
            scale: scale,
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(
            tester.takeException(),
            isNull,
            reason:
                'Friends overflows on $device at ${scale}x text — silently, '
                'in release.',
          );
        });

        testWidgets('the circle screen on $device at ${scale}x', (
          WidgetTester tester,
        ) async {
          await pumpScreen(
            tester,
            overrides: everything(),
            home: const CircleScreen(circleId: 'c1'),
            device: device,
            scale: scale,
          );
          await tester.pump(const Duration(milliseconds: 600));
          expect(find.text('Leave circle'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    /// The sheets, on the phone with the least room for them.
    for (final double scale in kTextScales) {
      testWidgets('the friend sheet and its pickers fit an SE at ${scale}x', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          overrides: everything(),
          device: kDevices.first,
          scale: scale,
        );
        // The name, not the card's centre: on a card with a fresh milestone
        // the centre is the MashaAllah button.
        await tester.ensureVisible(find.text(crowded.name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(crowded.name));
        await tester.pumpAndSettle();
        expect(find.text('Send a verse'), findsOneWidget);
        expect(find.text('Invite to a circle'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'friend sheet');

        await tester.tap(find.text('Send a verse'));
        await tester.pumpAndSettle();
        expect(find.textContaining('For Muhammad'), findsOneWidget);
        await tester.tap(find.text('Anxious'));
        await tester.pumpAndSettle();
        expect(find.text('Send'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'verse picker');
      });

      testWidgets('the create sheet fits an SE at ${scale}x', (
        WidgetTester tester,
      ) async {
        await pumpScreen(
          tester,
          overrides: everything(),
          device: kDevices.first,
          scale: scale,
        );
        await tester.ensureVisible(find.text('Start a circle'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start a circle'));
        await tester.pumpAndSettle();
        expect(find.text('Fajr on time'), findsWidgets);
        expect(find.text('All five'), findsOneWidget);
        expect(find.text('Tahajjud'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'create sheet');
      });
    }
  });
}

/// A stand-in for [FriendsActions] that records what it was asked to do.
///
/// It keeps the real controller's manners: a refusal is left in `state`
/// rather than thrown, which is the path the field actually reads.
class _FakeFriendsActions extends FriendsActions {
  _FakeFriendsActions({this.fail});

  final FriendAddError? fail;

  final List<String> added = <String>[];
  final List<(String, MilestoneKey)> cheers = <(String, MilestoneKey)>[];
  final List<bool> quiet = <bool>[];
  final List<(String, String)> verses = <(String, String)>[];
  final List<String> masjids = <String>[];
  final List<String> dismissed = <String>[];

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
  Future<void> remove(String uid) async {}

  @override
  Future<void> setQuiet(bool value) async => quiet.add(value);

  @override
  Future<void> cheer(String friendUid, MilestoneKey key) async =>
      cheers.add((friendUid, key));

  @override
  Future<void> sendVerse(String friendUid, String comfortId) async =>
      verses.add((friendUid, comfortId));

  @override
  Future<void> setJumuah(String masjid) async => masjids.add(masjid);

  @override
  Future<void> dismissInbox(String itemId) async => dismissed.add(itemId);

  @override
  Future<void> sendEid() async {}
}

/// A stand-in for [CircleActions] that records joins.
///
/// It keeps the real controller's manners: a refusal is left in `state`
/// rather than thrown, and the circle comes back once the join has landed.
class _FakeCircleActions extends CircleActions {
  _FakeCircleActions({this.fail = false});

  final bool fail;
  final List<String> joined = <String>[];

  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  @override
  Future<Circle?> join(String code) async {
    joined.add(code);
    state = const AsyncValue<void>.loading();
    if (fail) {
      state = AsyncValue<void>.error(
        const CircleJoinException(CircleJoinError.notFound),
        StackTrace.current,
      );
      return null;
    }
    state = const AsyncValue<void>.data(null);
    return Circle(
      id: 'joined',
      name: 'Fajr with the cousins',
      goal: CircleGoal.fajr,
      startsOn: Fmt.dayId(DateTime.now()),
      code: code,
      createdBy: 'other',
      members: const <String>['other', 'me'],
      createdAt: DateTime.now(),
    );
  }
}

/// Saved cards without SharedPreferences behind them.
class _FakeSaved extends SavedComforts {
  _FakeSaved(this.ids);

  final Set<String> ids;

  @override
  Set<String> build() => ids;

  @override
  Future<void> toggle(Comfort c) async {
    final Set<String> next = Set<String>.from(state);
    if (!next.remove(c.id)) next.add(c.id);
    state = next;
  }
}
