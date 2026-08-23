import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/core/widgets/app_scaffold.dart';
import 'package:noor/shell/app_shell.dart';

import 'test_fonts.dart';

/// The floating tab bar overlaps the body, so anything a screen pins to its
/// bottom can end up behind the glass — visible, but untappable. That is how
/// Tasbih's Reset and Count buttons were lost.
void main() {
  setUpAll(loadNoorFonts);

  testWidgets('bottom-anchored content clears the tab bar',
      (WidgetTester tester) async {
    const double screenHeight = 700;
    tester.view.physicalSize = const Size(393 * 3, screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: AppColors.midnight,
            extendBody: true,
            // Mirrors what AppShell hands its body.
            body: Builder(
              builder: (BuildContext context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  padding: MediaQuery.of(context).padding.copyWith(
                        bottom: MediaQuery.of(context).padding.bottom +
                            kBottomBarHeight,
                      ),
                ),
                child: const NightScaffold(
                  showOrnaments: false,
                  child: Column(
                    children: <Widget>[
                      Spacer(),
                      SizedBox(
                        key: ValueKey<String>('pinned'),
                        height: 44,
                        child: Text('Count'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottomNavigationBar: const BottomBarPreview(index: 0),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final double buttonBottom =
        tester.getRect(find.byKey(const ValueKey<String>('pinned'))).bottom;
    final double barTop =
        tester.getRect(find.byType(BottomBarPreview)).top;

    expect(
      buttonBottom,
      lessThanOrEqualTo(barTop + 0.5),
      reason: 'pinned content ends at $buttonBottom but the bar starts at '
          '$barTop — it is sitting under the glass and cannot be tapped',
    );
  });
}
