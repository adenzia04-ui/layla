import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_globe.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/shell/app_shell.dart';

import 'test_fonts.dart';

/// The bar is glass, so it has to be judged over real content. Rendered on a
/// blank ground it looks like a flat panel no matter how it is built.
void main() {
  setUpAll(loadNoorFonts);

  testWidgets('bottom bar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 260 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(NoorGlobe.preload);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.midnight,
            extendBody: true,
            body: NoorGlobe(
              prayer: PrayerId.isha,
              latitude: 3.139,
              longitude: 101.6869,
              radiusFactor: 0.9,
              centreY: 0.35,
            ),
            bottomNavigationBar: BottomBarPreview(index: 2),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 20));

    await expectLater(
      find.byType(BottomBarPreview),
      matchesGoldenFile('goldens/bottom_bar.png'),
    );
  });
}
