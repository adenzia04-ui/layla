import 'package:flutter/material.dart';
import 'package:noor/core/widgets/night_hero.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/splash/presentation/splash_screen.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  /// The splash paints edge to edge.
  ///
  /// It did not: the Stack shrink-wrapped to its widest non-positioned child,
  /// so the sky covered 238 of 393 logical pixels and the right-hand 39% of
  /// the screen was bare scaffold. It looked like a rendering glitch and was a
  /// missing `StackFit.expand`. Measured rather than eyeballed, because the
  /// seam sits at whatever width the longest line of text happens to be.
  Future<void> expectFullBleed(WidgetTester tester) async {
    final RenderBox hero = tester.renderObject<RenderBox>(
      find.byType(NightHero),
    );
    final Size view = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      hero.size.width,
      view.width,
      reason: 'the night sky is only ${hero.size.width} of ${view.width} wide',
    );
  }

  Future<void> shoot(WidgetTester tester, int ms, String name) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: SplashScreen(),
        ),
      ),
    );
    await tester.pump(Duration(milliseconds: ms));
    await expectFullBleed(tester);
    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/$name.png'),
    );

    // The splash hops to the next route once the 3.4s build-up has run and
    // been held for 0.9s. Tear the tree down first — _decideNextRoute checks
    // `mounted` — then let the timer run out, or the binding fails the test
    // for a pending timer. The drain has to outlast the hop, not the build.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  // Mid-draw and settled. The screenshot that prompted this redesign caught it
  // at the first of these, when only the arch had appeared — so it is worth
  // seeing what that moment actually looks like, not just the finished frame.
  //
  // Both times are phases of the build-up, not round numbers: the arch draws
  // over 0.51s–2.45s, so 1.4s is genuinely mid-draw, and 3.5s is past the end
  // of the animation but still short of the route hop.
  testWidgets('splash, arch drawing', (WidgetTester tester) async {
    await shoot(tester, 1400, 'splash_early');
  });

  testWidgets('splash, settled', (WidgetTester tester) async {
    await shoot(tester, 3500, 'splash_settled');
  });
}
