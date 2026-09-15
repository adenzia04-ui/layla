import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/features/onboarding/application/journey_controller.dart';
import 'package:noor/features/onboarding/presentation/steps/pledge_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

/// The promise is made by holding the button, so the hold has to survive a
/// thumb that is not perfectly still.
///
/// It did not. The button used GestureDetector's onTapDown/onTapUp, and the
/// tap recogniser abandons the gesture once the pointer passes kTouchSlop —
/// 18 logical pixels — firing onTapCancel. The fill rewound silently and the
/// promise could not be completed, with nothing on screen to explain why.
///
/// The drift below is deliberately just past that threshold: it fails on the
/// old GestureDetector and passes on the Listener, which is the only way to
/// know this test is measuring the fix and not agreeing with it by accident.
void main() {
  setUpAll(loadNoorFonts);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) =>
                  SingleChildScrollView(
                    child: const PledgeStep().body(
                      context,
                      ref,
                      ref.watch(journeyProvider),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Draws a signature, since the button does nothing until one exists.
  Future<void> sign(WidgetTester tester) async {
    final Finder pad = find.byType(CustomPaint).last;
    final Offset origin = tester.getCenter(pad);
    final TestGesture g = await tester.startGesture(origin);
    for (int i = 1; i <= 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await g.moveBy(const Offset(6, 3));
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a hold that drifts still completes the promise', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await pump(tester);
    await sign(tester);

    final Finder button = find.text('Hold to make your promise');
    expect(
      button,
      findsOneWidget,
      reason: 'the button should be live once a signature exists',
    );

    final TestGesture hold = await tester.startGesture(
      tester.getCenter(button),
    );

    // 24 logical pixels over the hold — past the 18px slop, and well
    // within what a thumb does while waiting for a button to fill.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      await hold.moveBy(const Offset(2.4, -1.2));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      container.read(journeyProvider).pledged,
      isTrue,
      reason:
          'the fill reversed part-way — a thumb that moves a pixel should '
          'not undo the promise',
    );
    await hold.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the fill spans the whole button, not just the label', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await sign(tester);

    final Finder button = find.text('Hold to make your promise');
    final TestGesture hold = await tester.startGesture(
      tester.getCenter(button),
    );
    await tester.pump(const Duration(milliseconds: 700));

    // The gold sweep is the only ColoredBox-alike inside the button; measuring
    // its box against the button's own is what catches a fill that has quietly
    // been given the label's width instead of the button's.
    final Rect fill = tester.getRect(
      find
          .descendant(
            of: find.byType(FractionallySizedBox),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final Rect frame = tester.getRect(find.byType(FractionallySizedBox).first);
    final Rect label = tester.getRect(button);

    expect(
      frame.width,
      greaterThan(label.width + 40),
      reason:
          'the fill track is ${frame.width} wide but the label is only '
          '${label.width} — the sweep is sized to the words, not the button',
    );
    expect(fill.left, closeTo(frame.left, 0.5));

    await hold.up();
    await tester.pumpAndSettle();
  });

  testWidgets('letting go early makes no promise', (WidgetTester tester) async {
    final ProviderContainer container = await pump(tester);
    await sign(tester);

    final TestGesture hold = await tester.startGesture(
      tester.getCenter(find.text('Hold to make your promise')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await hold.up();
    await tester.pumpAndSettle();

    expect(
      container.read(journeyProvider).pledged,
      isFalse,
      reason: 'a promise must take the full hold, or the hold means nothing',
    );
  });
}
