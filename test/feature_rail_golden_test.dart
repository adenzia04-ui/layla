import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_flame.dart';
import 'package:noor/core/widgets/tasbih_beads.dart';
import 'package:noor/features/home/presentation/widgets/feature_rail.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  /// Real iPhone width — at the default 800x600 the tiles render far larger
  /// than they ever are on a phone and the proportions mislead.
  void sizeAsPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 420 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('feature grid renders', (WidgetTester tester) async {
    sizeAsPhone(tester);
    await tester.pumpWidget(_harness());
    await expectLater(
      find.byType(FeatureRail),
      matchesGoldenFile('goldens/feature_rail.png'),
    );
  });

  testWidgets('tile content is centred', (WidgetTester tester) async {
    // Guards a real bug: a Stack lays non-positioned children out at topStart
    // at their intrinsic size, so the icon and label drifted left and up.
    sizeAsPhone(tester);
    await tester.pumpWidget(_harness());

    for (final String label in <String>['Qibla', 'Tasbih', 'Prayer Times']) {
      final Finder text = find.text(label);
      final Finder tile = find
          .ancestor(of: text, matching: find.byType(InkWell))
          .first;

      expect(
        (tester.getCenter(text).dx - tester.getCenter(tile).dx).abs(),
        lessThan(1),
        reason: '"$label" is not horizontally centred in its tile',
      );
    }

    final Finder tile = find
        .ancestor(of: find.text('Qibla'), matching: find.byType(InkWell))
        .first;
    final Rect box = tester.getRect(tile);
    final Rect label = tester.getRect(find.text('Qibla'));

    // Measure the chip, not the icon glyph: the icon sits inset inside the
    // 44px chip, so measuring it reports a false 11.5px offset.
    final Rect chip = tester.getRect(
      find
          .descendant(
            of: tile,
            matching: find.byKey(const ValueKey<String>('feature-chip')),
          )
          .first,
    );

    expect(
      ((chip.top - box.top) - (box.bottom - label.bottom)).abs(),
      lessThan(2),
      reason: 'tile content is not vertically centred',
    );
  });
}

/// The grid under test.
///
/// One tree shared by both cases — a duplicated inline copy meant a change
/// landed in one and not the other, and the golden quietly kept rendering the
/// old icon.
Widget _harness() => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ColoredBox(
    color: AppColors.midnight,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FeatureRail(
          items: <FeatureItem>[
            FeatureItem(
              label: 'Prayer Times',
              icon: Icons.access_time_rounded,
              onTap: () {},
            ),
            FeatureItem(
              label: 'Qibla',
              icon: Icons.explore_rounded,
              accent: const Color(0xFF5AA6E8),
              onTap: () {},
            ),
            FeatureItem(
              label: 'Tasbih',
              icon: Icons.radio_button_checked_rounded,
              accent: AppColors.emerald,
              iconWidget: const TasbihBeads(size: 26),
              onTap: () {},
            ),
            FeatureItem(
              label: 'Tahajjud',
              icon: Icons.bedtime_rounded,
              accent: const Color(0xFFB98FE0),
              badge: '12',
              onTap: () {},
            ),
            FeatureItem(
              label: 'Tahajjud Stories',
              icon: Icons.menu_book_rounded,
              accent: AppColors.goldSoft,
              onTap: () {},
            ),
            FeatureItem(
              label: 'Prayer Streak',
              icon: Icons.local_fire_department_rounded,
              accent: AppColors.ember,
              iconWidget: const NoorFlame(size: 26, glow: false),
              onTap: () {},
            ),
          ],
        ),
      ),
    ),
  ),
);
