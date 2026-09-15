import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/shell/app_shell.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  testWidgets('every tab is tappable', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<int> taps = <int>[];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.midnight,
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: BottomBarPreview(index: 0, onTap: taps.add),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    for (final String label in <String>['Home', 'Tahajjud', 'Soul']) {
      await tester.tap(find.text(label), warnIfMissed: false);
      await tester.pump();
    }

    expect(
      taps,
      <int>[0, 1, 2],
      reason:
          'taps that reached the bar: $taps — a tab that records nothing '
          'is being swallowed before it gets there',
    );
  });

  testWidgets('dragging the bar moves the selection', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<int> picked = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.midnight,
            extendBody: true,
            body: const SizedBox.expand(),
            bottomNavigationBar: BottomBarPreview(index: 0, onTap: picked.add),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Drag from the first tab across to the last. The bar is a pill
    // narrower than the screen, so measure the pill — the part that takes
    // the drag — rather than the full-width slot it floats in.
    final Rect bar = tester.getRect(
      find
          .descendant(
            of: find.byType(BottomBarPreview),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final Offset start = Offset(bar.left + bar.width * 0.1, bar.center.dy);
    final Offset end = Offset(bar.left + bar.width * 0.92, bar.center.dy);

    final TestGesture g = await tester.startGesture(start);
    await tester.pump();
    await g.moveTo(end);
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      picked,
      isNotEmpty,
      reason:
          'dragging across the bar selected nothing — the lens is not '
          'following the finger',
    );
    expect(
      picked.last,
      2,
      reason: 'released over the last tab but got ${picked.last}',
    );
  });
}
