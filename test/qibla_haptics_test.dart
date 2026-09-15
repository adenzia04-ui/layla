import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/prayer_times/application/prayer_times_controller.dart';
import 'package:noor/core/services/location_service.dart';
import 'package:noor/features/qibla/application/qibla_controller.dart';
import 'package:noor/features/qibla/presentation/qibla_screen.dart';

import 'test_fonts.dart';

/// The Qibla screen is used with the phone held out and the eyes elsewhere, so
/// the haptics are the interface, not a garnish. They are also invisible to a
/// golden and easy to break without noticing.
void main() {
  setUpAll(loadNoorFonts);

  final StateProvider<double> heading = StateProvider<double>((Ref ref) => 0);

  /// Kaaba due south, so `offBy` is simply the distance from 180°.
  late List<String> felt;

  Future<ProviderContainer> pump(WidgetTester tester, double start) async {
    // A phone-shaped surface: the default 800x600 test view overflows this
    // screen, and the exception masks whatever the haptics did.
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    felt = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          felt.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        // Never completes, so the header falls back to an empty place label
        // without reaching for the device's location.
        placeProvider.overrideWith((Ref ref) => Completer<NoorPlace>().future),
        qiblaProvider.overrideWith(
          (Ref ref) => AsyncValue<QiblaState>.data(
            QiblaState(
              qiblaBearing: 180,
              heading: ref.watch(heading),
              hasSensor: true,
              needsCalibration: false,
              distanceKm: 6000,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(heading.notifier).state = start;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: QiblaScreen(),
        ),
      ),
    );
    felt.clear();
    return container;
  }

  Future<void> turnTo(
    WidgetTester tester,
    ProviderContainer container,
    double to,
  ) async {
    container.read(heading.notifier).state = to;
    await tester.pump();
  }

  testWidgets('a small turn far from the Qibla does not tick', (
    WidgetTester tester,
  ) async {
    // 80° off, so the coarse 15° step applies.
    final ProviderContainer c = await pump(tester, 100);
    await turnTo(tester, c, 110);
    expect(felt, isEmpty);
    await turnTo(tester, c, 118);
    expect(felt, <String>['HapticFeedbackType.selectionClick']);
  });

  testWidgets('the ticks close up as the Qibla gets nearer', (
    WidgetTester tester,
  ) async {
    // 15° off: past the 20° mark, so the 4° step applies and a turn that would
    // be ignored out in the open now registers.
    final ProviderContainer c = await pump(tester, 165);
    await turnTo(tester, c, 170);
    expect(felt, <String>['HapticFeedbackType.selectionClick']);
  });

  testWidgets('turning past north is a small step, not a 359° leap', (
    WidgetTester tester,
  ) async {
    // Reading 359 then 1 is a two-degree nudge. Subtracting them without
    // wrapping gives 358, which would fire a tick on every crossing of north.
    final ProviderContainer c = await pump(tester, 359);
    await turnTo(tester, c, 1);
    expect(felt, isEmpty);
  });

  testWidgets('arriving on the Qibla gives one firm pulse, then silence', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, 160);
    await turnTo(tester, c, 178);
    expect(felt, <String>['HapticFeedbackType.heavyImpact']);

    // Held roughly still, with the compass jittering a degree or two. Ticking
    // here would buzz continuously in the hand of someone already lined up.
    felt.clear();
    await turnTo(tester, c, 181);
    await turnTo(tester, c, 177);
    expect(felt, isEmpty);
  });
}
