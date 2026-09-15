import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/features/tasbih/application/tasbih_controller.dart';
import 'package:noor/features/tasbih/application/tasbih_view.dart';
import 'package:noor/features/tasbih/presentation/widgets/tasbih_mark.dart';
import 'package:noor/features/tasbih/presentation/widgets/tasbih_ring.dart';
import 'package:noor/features/tasbih/presentation/widgets/tasbih_strand.dart';
import 'package:noor/features/tasbih/domain/sunnah_routine.dart';
import 'package:noor/features/tasbih/presentation/tasbih_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  Future<ProviderContainer> pump(WidgetTester tester, TasbihMode mode) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        tasbihPaceProvider.overrideWithValue(false),
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(tasbihProvider.notifier).setMode(mode);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: TasbihScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the beads strand is an alternative to the ring', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.manual);
    expect(find.byType(TasbihRing), findsOneWidget);
    expect(find.byType(TasbihStrand), findsNothing);

    c.read(counterStyleProvider.notifier).choose(CounterStyle.gold);
    await tester.pumpAndSettle();
    expect(find.byType(TasbihStrand), findsOneWidget);
    expect(
      find.byType(TasbihRing),
      findsNothing,
      reason: 'one counter at a time, not both',
    );

    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_beads.png'),
    );
  });

  testWidgets('counting on beads still counts', (WidgetTester tester) async {
    final ProviderContainer c = await pump(tester, TasbihMode.manual);
    c.read(counterStyleProvider.notifier).choose(CounterStyle.gold);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TasbihStrand));
    await tester.pumpAndSettle();
    expect(c.read(tasbihProvider).count, 1);
  });

  testWidgets('the Layla Pro mark is a counter too', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.manual);
    c.read(counterStyleProvider.notifier).choose(CounterStyle.layla);
    await tester.pumpAndSettle();
    // Image decoding is real async work; without this the golden shows an
    // empty box where the mark should be and proves nothing.
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/layla_mark.png'),
        tester.element(find.byType(TasbihMark)),
      );
    });
    await tester.pumpAndSettle();

    expect(find.byType(TasbihMark), findsOneWidget);
    expect(find.byType(TasbihRing), findsNothing);

    await tester.tap(find.byType(TasbihMark));
    await tester.pumpAndSettle();
    expect(c.read(tasbihProvider).count, 1);

    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_layla.png'),
    );
  });

  testWidgets('every counter style is offered', (WidgetTester tester) async {
    await pump(tester, TasbihMode.manual);
    await tester.tap(find.byTooltip('Choose the counter'));
    await tester.pumpAndSettle();

    for (final CounterStyle s in CounterStyle.values) {
      expect(find.text(s.label), findsOneWidget, reason: '${s.label} missing');
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tasbih_styles.png'),
    );
  });

  testWidgets('the chosen counter survives a restart', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.manual);
    c.read(counterStyleProvider.notifier).choose(CounterStyle.jade);
    await tester.pumpAndSettle();
    // The pref is written without awaiting so the swap is instant.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(c.read(prefsProvider).tasbihStyle, 'jade');
  });

  testWidgets('sunnah mode shows the sequence', (WidgetTester tester) async {
    await pump(tester, TasbihMode.sunnah);
    expect(find.text('Sunnah'), findsOneWidget);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('SubhanAllah'), findsWidgets);
    // The picker names the chosen sunnah and its total.
    expect(find.text('After prayer'), findsOneWidget);
    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_sunnah.png'),
    );
  });

  testWidgets('the hundredth count brings up the message', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.sunnah);

    for (int i = 0; i < 99; i++) {
      c.read(tasbihProvider.notifier).increment();
    }
    await tester.pumpAndSettle();
    expect(find.text('Masha\'Allah'), findsNothing, reason: 'not yet');

    c.read(tasbihProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(find.text('Masha\'Allah'), findsOneWidget);
    expect(find.textContaining('Sahih Muslim 596a'), findsOneWidget);
    // The count that belongs to this narration, not Abu Hurairah's.
    expect(find.textContaining('thirty-four takbir'), findsOneWidget);
    expect(find.textContaining('foam of the sea'), findsNothing);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tasbih_round_complete.png'),
    );
  });

  testWidgets('a x3 routine is read from the text, not tapped out', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.sunnah);
    c.read(tasbihProvider.notifier).setRoutine(SunnahRoutine.juwayriyah);
    await tester.pumpAndSettle();

    // The words, the way to say them, and a confirmation -- no tap-ring.
    expect(find.textContaining('adada khalqihi'), findsWidgets);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Recited 0 of 3'), findsOneWidget);

    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_recite.png'),
    );
  });

  testWidgets('before sleep protection opens on Ayat al-Kursi', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.sunnah);
    c
        .read(tasbihProvider.notifier)
        .setRoutine(SunnahRoutine.beforeSleepProtection);
    await tester.pumpAndSettle();

    expect(find.text("QUR'AN 2:255"), findsOneWidget);
    expect(find.text('Done'), findsWidgets, reason: 'x1 advances on one press');
    expect(find.text('Recite, then tap Done'), findsOneWidget);

    await expectLater(
      find.byType(TasbihScreen),
      matchesGoldenFile('goldens/tasbih_kursi.png'),
    );
  });

  testWidgets('each Done moves to the next passage, then finishes', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = await pump(tester, TasbihMode.sunnah);
    final TasbihController t = c.read(tasbihProvider.notifier);
    t.setRoutine(SunnahRoutine.beforeSleepProtection);
    await tester.pumpAndSettle();

    // Ayat al-Kursi x1 -> al-Ikhlas
    t.increment();
    await tester.pumpAndSettle();
    expect(c.read(tasbihProvider).dhikr.name, 'Al-Ikhlas');

    // three each through the quls
    for (final String next in <String>['Al-Falaq', 'An-Nas', 'SubhanAllah']) {
      for (int i = 0; i < 3; i++) {
        t.increment();
      }
      await tester.pumpAndSettle();
      expect(c.read(tasbihProvider).dhikr.name, next);
    }

    // then the tasbih of Fatimah, and the finish message on the hundredth
    for (int i = 0; i < 33 + 33 + 33; i++) {
      t.increment();
    }
    await tester.pumpAndSettle();
    expect(find.text("Masha'Allah"), findsNothing, reason: 'one short');

    t.increment();
    await tester.pumpAndSettle();
    expect(find.text("Masha'Allah"), findsOneWidget);
    expect(find.text('110 dhikr'), findsOneWidget);
  });

  testWidgets('the picker lists every sunnah with its reference', (
    WidgetTester tester,
  ) async {
    await pump(tester, TasbihMode.sunnah);
    await tester.tap(find.text('After prayer'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a sunnah'), findsOneWidget);
    for (final String name in <String>[
      'Before sleep',
      'Istighfar',
      "Juwayriyah's tasbih",
      'Morning & evening tasbih',
    ]) {
      expect(find.text(name), findsWidgets, reason: '$name missing');
    }
    // Raditu is said morning and evening, so it is listed under both — and
    // carries its grading in both places rather than only the first.
    expect(find.text('Raditu billahi rabban'), findsNWidgets(2));
    expect(find.text('Hasan'), findsNWidgets(2));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/tasbih_routine_sheet.png'),
    );
  });
}
