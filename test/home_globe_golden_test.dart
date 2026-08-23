import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_globe.dart';
import 'package:noor/features/home/presentation/widgets/next_prayer_hero.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';

import 'test_fonts.dart';

/// Reproduces the dashboard's globe *layer* — background, the 470pt band and
/// the fade — rather than the globe alone. The globe-only golden cannot show a
/// seam between the sphere and what sits behind it, which is exactly the class
/// of bug this catches.
void main() {
  setUpAll(loadNoorFonts);

  const Size screen = Size(393, 852);

  testWidgets('home globe layer', (WidgetTester tester) async {
    tester.view.physicalSize = Size(screen.width * 3, screen.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(NoorGlobe.preload);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.midnight,
          body: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppColors.nightSky),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 820,
                // The sphere is taller than this band, and `Positioned` does not
                // clip. Without this, the overflow escapes the ShaderMask — which
                // only masks inside its own box — and repaints at full opacity
                // exactly where the fade reached zero, drawing a hard seam across
                // the Earth.
                child: ClipRect(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                      ],
                      stops: <double>[0, 0.62, 0.9],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: const NoorGlobe(
                      prayer: PrayerId.isha,
                      latitude: 3.139,
                      longitude: 101.6869,
                      radiusFactor: 0.60,
                      centreY: 0.42,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 300,
                left: 20,
                right: 20,
                child: NextPrayerHero(
                  now: DateTime(2026, 8, 21, 0, 8, 35),
                  // Dhuhr on purpose. Its palette ink is a dark brown chosen
                  // for a light card, so it is the case that goes invisible
                  // over the Earth — an Isha fixture (light ink) passes even
                  // when the colour logic is wrong.
                  next: PrayerSlot(
                    id: PrayerId.dhuhr,
                    start: DateTime(2026, 8, 21, 13, 17),
                    end: DateTime(2026, 8, 21, 16, 32),
                  ),
                  nextIsTomorrow: false,
                  previous: PrayerSlot(
                    id: PrayerId.isha,
                    start: DateTime(2026, 8, 20, 20, 30),
                    end: DateTime(2026, 8, 21, 6),
                  ),
                  following: PrayerSlot(
                    id: PrayerId.dhuhr,
                    start: DateTime(2026, 8, 21, 13, 17),
                    end: DateTime(2026, 8, 21, 16, 30),
                  ),
                  locationLabel: 'Seri Kembangan, Malaysia',
                  onEarth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 20));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/home_globe_layer.png'),
    );
  });
}
