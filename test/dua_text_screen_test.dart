import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/dua/domain/dua_catalogue.dart';
import 'package:noor/features/dua/presentation/dua_test_screen.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  testWidgets('the text section lists every category', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DuaTestScreen(),
      ),
    );
    // The 223KB of JSON is decoded off the fake clock.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    for (final String name in <String>[
      'Prayer',
      'Morning & Evening',
      'Sleep',
      'Daily Life',
      'Protection',
      'Travel',
      'Food & Drink',
      'Family & People',
    ]) {
      expect(find.text(name), findsOneWidget, reason: '$name missing');
    }

    // Same numbers as the picture library, so the two views never look like
    // they disagree about a category.
    for (final DuaCategory c in duaCategories) {
      expect(
        find.text('${c.count}'),
        findsWidgets,
        reason: '${c.title} should show ${c.count} sections',
      );
    }

    await expectLater(
      find.byType(DuaTestScreen),
      matchesGoldenFile('goldens/dua_text_categories.png'),
    );
  });

  testWidgets('tapping Protection opens its sections', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: DuaTestScreen(),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Protection'));
    await tester.pumpAndSettle();

    for (final String s in <String>[
      'Worry and Grief',
      'Anguish',
      'Meeting an Adversary or Ruler',
    ]) {
      expect(find.text(s), findsOneWidget, reason: '$s missing');
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dua_text_protection.png'),
    );
  });
}
