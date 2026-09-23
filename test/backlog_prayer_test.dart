import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/features/home/presentation/widgets/prayer_choice_card.dart';
import 'package:noor/features/prayer_lock/domain/prayer_session.dart';
import 'package:noor/features/prayer_lock/presentation/widgets/mat_scan_offer.dart';
import 'package:noor/features/premium/application/premium_store.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A prayer left open since the morning, answered at Maghrib.
///
/// The mat scan proves "I am on the mat now". It cannot prove that about a
/// Fajr being settled eight hours later, so asking for it there was four
/// scans in a row that meant nothing — and was reported as the app
/// "asking again and again for pictures". The backlog is one tap; only the
/// prayer whose time it is asks for the mat.
void main() {
  PrayerSession fajr({required bool isCurrent}) => PrayerSession(
    prayer: PrayerId.fajr,
    startedAt: DateTime(2026, 9, 23, 5, 55),
    endsAt: DateTime(2026, 9, 23, 6, 25),
    status: PrayerStatus.pending,
    isCurrent: isCurrent,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool pro,
    required bool isCurrent,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          prefsProvider.overrideWithValue(PrefsService(prefs)),
          isProProvider.overrideWithValue(pro),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerChoiceCard(session: fajr(isCurrent: isCurrent)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('A prayer from earlier in the day', () {
    testWidgets('is one tap even with Premium, and says so', (
      WidgetTester tester,
    ) async {
      await pump(tester, pro: true, isCurrent: false);
      expect(find.text('Fajr is still open'), findsOneWidget);
      expect(find.textContaining('no photo'), findsOneWidget);
      expect(find.text('I have prayed'), findsOneWidget);
      expect(find.textContaining('photo of your mat'), findsNothing);
      // Premium is not sold to someone who has it, backlog or not.
      expect(find.byType(MatScanOffer), findsNothing);
    });

    testWidgets('the current prayer still asks Premium for the mat', (
      WidgetTester tester,
    ) async {
      await pump(tester, pro: true, isCurrent: true);
      expect(find.text('It is time for Fajr'), findsOneWidget);
      expect(find.textContaining('photo of your mat'), findsOneWidget);
    });
  });

  test('sessions of the same prayer differ by whether it is current', () {
    expect(fajr(isCurrent: true), isNot(equals(fajr(isCurrent: false))));
  });
}
