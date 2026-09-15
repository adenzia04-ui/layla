import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/theme/app_typography.dart';
import 'package:noor/core/widgets/ticking_digits.dart';

import 'test_fonts.dart';

/// Captures the squash mid-change. A golden at rest would look identical to
/// plain `Text` and prove nothing about the animation.
int _elapsed = 0;

void main() {
  setUpAll(loadNoorFonts);

  testWidgets('digits squash mid-change', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 140 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget frame(String value) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: TickingDigits(
            value: value,
            style: AppType.clock.copyWith(color: AppColors.cream),
          ),
        ),
      ),
    );

    await tester.pumpWidget(frame('12:39'));
    await tester.pump();

    // Walk the change so the whole motion is covered, not just one instant:
    // entering the squash, deepest compression, and coming out of it.
    await tester.pumpWidget(frame('12:40'));
    for (final (int ms, String name) in <(int, String)>[
      (110, 'enter'),
      (230, 'mid'),
      (340, 'exit'),
    ]) {
      await tester.pump(Duration(milliseconds: ms - _elapsed));
      _elapsed = ms;
      await expectLater(
        find.byType(TickingDigits),
        matchesGoldenFile('goldens/ticking_digits_$name.png'),
      );
    }

    // And settled again.
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(TickingDigits),
      matchesGoldenFile('goldens/ticking_digits_rest.png'),
    );
  });

  testWidgets('every character survives repeated changes', (
    WidgetTester tester,
  ) async {
    Widget frame(String v) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: TickingDigits(
            value: v,
            style: AppType.clock.copyWith(color: AppColors.cream),
          ),
        ),
      ),
    );

    // Tick like a real clock. A single change cannot expose this: the fault
    // only appears once a glyph has *finished* animating, which is when the
    // controller sits at its end value and the crossfade collapses to nothing.
    await tester.pumpWidget(frame('8:10'));
    await tester.pump();

    for (final String v in <String>['8:11', '8:12', '8:13']) {
      await tester.pumpWidget(frame(v));
      await tester.pump(const Duration(milliseconds: 600));

      final Iterable<Text> texts = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(TickingDigits),
          matching: find.byType(Text),
        ),
      );
      final String rendered = texts.map((Text t) => t.data ?? '').join();
      expect(
        rendered,
        v,
        reason:
            'after settling on "$v" the widget rendered "$rendered" — '
            'a character vanished instead of coming to rest',
      );
    }
  });

  testWidgets('the clock does not shift sideways as it ticks', (
    WidgetTester tester,
  ) async {
    // The bounce was never the animation — it was the type. Inter's
    // proportional digits make ":11" narrower than ":40", so the row's width
    // changed every second and `Center` slid the whole clock across.
    Widget frame(String clock, String secs) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: Row(
            // Keyed: `TickingDigits` builds a Row of its own, so byType
            // matches several.
            key: const ValueKey<String>('clock-row'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              TickingDigits(
                value: clock,
                style: AppType.clock.copyWith(color: AppColors.cream),
              ),
              TickingDigits(
                value: secs,
                style: AppType.clockSuffix.copyWith(
                  fontSize: 26,
                  color: AppColors.cream,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(frame('12:11', ':11'));
    await tester.pump(const Duration(milliseconds: 600));
    final double narrow = tester
        .getRect(find.byKey(const ValueKey<String>('clock-row')))
        .width;

    await tester.pumpWidget(frame('12:40', ':40'));
    await tester.pump(const Duration(milliseconds: 600));
    final double wide = tester
        .getRect(find.byKey(const ValueKey<String>('clock-row')))
        .width;

    expect(
      (wide - narrow).abs(),
      lessThan(0.5),
      reason:
          'width changed by ${(wide - narrow).abs()}px between ":11" and '
          '":40" — the digits are not tabular, so the clock will slide',
    );
  });
}
