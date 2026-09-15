import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fonts.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/noor_flame.dart';

/// Renders the flame to a golden PNG so its shape can be checked without
/// building and installing the whole app.
void main() {
  setUpAll(loadNoorFonts);

  testWidgets('flame renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: AppColors.midnight,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                NoorFlame(size: 120),
                NoorFlame(size: 56),
                NoorFlame(size: 28, glow: false),
                NoorFlame(size: 56, dimmed: true),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byType(Row), matchesGoldenFile('goldens/flame.png'));
  });
}
