import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_globe.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';

import 'test_fonts.dart';

/// Shooting stars are easy to break silently — they are visible for 1.7s out of
/// every 20, so a change that stops them drawing looks exactly like a quiet
/// stretch of sky. This counts lit pixels instead of trusting the eye.
void main() {
  setUpAll(loadNoorFonts);

  const Size band = Size(393, 852);

  /// Lit pixels in the sky strip above the globe, at [ms] into the spin.
  Future<int> litSky(WidgetTester tester, int ms) async {
    tester.view.physicalSize = Size(band.width * 3, band.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(NoorGlobe.preload);
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.midnight,
          child: NoorGlobe(
            prayer: PrayerId.isha,
            latitude: 3.139,
            longitude: 101.6869,
            radiusFactor: 0.60,
            centreY: 0.42,
          ),
        ),
      ),
    );
    await tester.pump(Duration(milliseconds: ms));

    final RenderRepaintBoundary box = tester
        .renderObject<RenderRepaintBoundary>(find.byType(NoorGlobe));
    late final ByteData data;
    late final int w;
    late final int h;
    await tester.runAsync(() async {
      // toImageSync defaults to a pixel ratio of 1 regardless of the view, so
      // take the dimensions from the image rather than from the logical size.
      final ui.Image image = box.toImageSync(pixelRatio: 3);
      w = image.width;
      h = image.height;
      data = (await image.toByteData())!;
      image.dispose();
    });

    // Only the strip above the horizon: centreY 0.42 less a 0.60 radius leaves
    // roughly the top 120 logical pixels, and the globe itself is far brighter
    // than anything in the sky.
    final int rows = (h * 100 / band.height).round();
    int lit = 0;
    for (int i = 0; i < w * rows * 4; i += 4) {
      if (data.getUint8(i) > 150) lit++;
    }
    return lit;
  }

  testWidgets('a meteor crosses the sky mid-slot and not between slots', (
    WidgetTester tester,
  ) async {
    // Seven slots across the 140s spin puts a slot at 20s; the flight window is
    // the first 8.5% of it, so 0.85s in is mid-flight and 10s in is empty sky.
    final int flight = await litSky(tester, 850);
    final int quiet = await litSky(tester, 10000);

    // Measured: 672 lit against 427 for empty sky, so the streak is worth about
    // 245 pixels at this threshold — far less than its full length, because
    // most of the gradient tail falls under it. The bound guards against the
    // streak vanishing altogether, not against the artwork being retuned.
    expect(
      flight,
      greaterThan(quiet + 150),
      reason: 'expected a streak at 0.85s; lit=$flight vs quiet sky $quiet',
    );
  });
}
