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

/// The prayer-mat scan, as somebody without Premium sees it.
///
/// It used to be drawn for nobody. A free confirmation is one honest tap and
/// the streak moves the same way, which is right — but the paid alternative
/// was absent from the one screen where a person decides how to confirm a
/// prayer. Read from a phone rather than from the code, a feature that is
/// absent and a feature that is broken look identical, and it was reported as
/// broken: "there is still no option to scan the prayer mat."
///
/// So the rule is not "the scan is gated" — it always was. The rule is that
/// the gate is *visible*.
void main() {
  final PrayerSession session = PrayerSession(
    prayer: PrayerId.asr,
    startedAt: DateTime(2026, 9, 19, 16, 10),
    endsAt: DateTime(2026, 9, 19, 16, 40),
    status: PrayerStatus.pending,
  );

  Future<void> pump(WidgetTester tester, {required bool pro}) async {
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
              child: PrayerChoiceCard(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('The mat scan is offered, not hidden', () {
    testWidgets('somebody without Premium is told it exists', (
      WidgetTester tester,
    ) async {
      await pump(tester, pro: false);
      expect(find.byType(MatScanOffer), findsOneWidget);
      expect(find.textContaining('scan your prayer mat'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
    });

    testWidgets('and can still confirm with one tap', (
      WidgetTester tester,
    ) async {
      // The offer must not replace the free path or crowd it out — the whole
      // point is that a free confirmation stays one honest tap.
      await pump(tester, pro: false);
      expect(find.text('I have prayed'), findsOneWidget);
    });

    testWidgets('somebody with Premium is not sold what they own', (
      WidgetTester tester,
    ) async {
      await pump(tester, pro: true);
      expect(find.byType(MatScanOffer), findsNothing);
      expect(find.text('Premium'), findsNothing);
    });
  });
}
