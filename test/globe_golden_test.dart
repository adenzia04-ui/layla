import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_globe.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  /// The exact box the globe gets on the dashboard — judging it at any other
  /// size is misleading, as an earlier pass proved.
  const Size band = Size(390, 470);

  Future<void> render(WidgetTester tester, PrayerId prayer, String name) async {
    tester.view.physicalSize = Size(band.width * 3, band.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Image decoding is real async; the fake clock in a widget test will not
    // advance it.
    await tester.runAsync(NoorGlobe.preload);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.midnight,
          child: NoorGlobe(
            prayer: prayer,
            // Kuala Lumpur — Asia and Australia face the viewer.
            latitude: 3.139,
            longitude: 101.6869,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 20));
    await expectLater(
      find.byType(NoorGlobe),
      matchesGoldenFile('goldens/globe_$name.png'),
    );
  }

  testWidgets('globe at night', (WidgetTester tester) =>
      render(tester, PrayerId.isha, 'isha'),);

  testWidgets('globe at maghrib', (WidgetTester tester) =>
      render(tester, PrayerId.maghrib, 'maghrib'),);
}
