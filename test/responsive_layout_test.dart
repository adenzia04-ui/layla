import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noor/core/theme/app_theme.dart';
import 'package:noor/core/widgets/app_button.dart';
import 'package:noor/features/profile/domain/avatar_crop.dart';
import 'package:noor/features/profile/presentation/avatar_crop_screen.dart';
import 'package:noor/features/tasbih/application/tasbih_controller.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/features/home/presentation/widgets/prayer_choice_card.dart';
import 'package:noor/features/home/presentation/widgets/prayer_grid.dart';
import 'package:noor/features/home/presentation/widgets/today_progress_card.dart';
import 'package:noor/features/prayer_lock/domain/prayer_session.dart';
import 'package:noor/core/services/location_service.dart';
import 'package:noor/features/prayer_times/application/prayer_times_controller.dart';
import 'package:noor/features/qibla/application/qibla_controller.dart';
import 'package:noor/features/qibla/presentation/qibla_screen.dart';
import 'package:noor/features/tasbih/presentation/tasbih_screen.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';
import 'package:noor/shell/app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_sizes.dart';
import 'test_fonts.dart';

/// Layla Pro is developed on a 17 Pro Max and installed on whatever phone a friend
/// happens to own. Those are 65 points apart in width and 289 in height, and
/// nothing in the app reads the screen size — every layout is expected to
/// absorb that difference on its own.
///
/// This is the instrument that says whether it does. A RenderFlex that runs out
/// of room reports an overflow through FlutterError, which `takeException`
/// surfaces as a test failure. That matters because **release builds do not
/// show the yellow stripes** — on a real small phone the overflow is silent and
/// simply clips, so a shaved-off button reaches a user who never reports it.
void main() {
  setUpAll(loadNoorFonts);

  final DateTime date = DateTime(2026, 8, 21);
  DateTime at(int h, int m) => DateTime(2026, 8, 21, h, m);

  final PrayerSchedule schedule = PrayerSchedule(
    date: date,
    slots: <PrayerSlot>[
      PrayerSlot(id: PrayerId.fajr, start: at(5, 52), end: at(7, 11)),
      PrayerSlot(id: PrayerId.sunrise, start: at(7, 11), end: at(13, 17)),
      PrayerSlot(id: PrayerId.dhuhr, start: at(13, 17), end: at(16, 32)),
      PrayerSlot(id: PrayerId.asr, start: at(16, 32), end: at(19, 23)),
      PrayerSlot(id: PrayerId.maghrib, start: at(19, 23), end: at(20, 33)),
      PrayerSlot(id: PrayerId.isha, start: at(20, 33), end: at(23, 59)),
    ],
    tahajjud: TahajjudWindow(start: at(2, 0), end: at(5, 52)),
    qiblaBearing: 292,
    latitude: 3.139,
    longitude: 101.6869,
  );

  /// Renders [build] on every phone at both ends of the text-scale clamp.
  ///
  /// One test per device rather than one test for all of them: when this fails
  /// the name of the failing test is the answer — you learn it is the SE at
  /// 1.3x without reading a stack trace.
  void matrix(String what, Widget Function() build) {
    for (final Device device in kDevices) {
      for (final double scale in kTextScales) {
        testWidgets('$what fits $device at ${scale}x', (
          WidgetTester tester,
        ) async {
          useDevice(tester, device);
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            ProviderScope(
              overrides: <Override>[
                tasbihPaceProvider.overrideWithValue(false),
                prefsProvider.overrideWithValue(PrefsService(prefs)),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: asDevice(
                  device: device,
                  textScale: scale,
                  child: Scaffold(
                    backgroundColor: AppColors.midnight,
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: build(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));

          expect(
            tester.takeException(),
            isNull,
            reason:
                '$what overflows on $device at ${scale}x text. On a real '
                'phone this clips silently — no stripes in release.',
          );
        });
      }
    }
  }

  matrix(
    'the prayer grid',
    () => PrayerGrid(
      schedule: schedule,
      now: at(17, 0),
      day: PrayerDay.empty('2026-08-21'),
    ),
  );

  matrix(
    'the three choices',
    () => PrayerChoiceCard(
      session: PrayerSession(
        prayer: PrayerId.asr,
        startedAt: at(16, 32),
        endsAt: at(19, 23),
        status: PrayerStatus.pending,
      ),
    ),
  );

  matrix(
    "today's progress",
    () => TodayProgressCard(
      day: PrayerDay.empty('2026-08-21'),
      currentStreak: 12,
      reopenable: const <PrayerId>{PrayerId.asr},
      choices: PrayerChoiceCard(
        session: PrayerSession(
          prayer: PrayerId.asr,
          startedAt: at(16, 32),
          endsAt: at(19, 23),
          status: PrayerStatus.pending,
        ),
      ),
    ),
  );

  matrix('the tab bar', () => const BottomBarPreview(index: 0));

  /// Full screens, given the real screen height and no scroll view to hide in.
  ///
  /// Tasbih and Qibla are the only two screens in the app that do not scroll —
  /// a bead strand and a compass, both sized to the window on purpose. That
  /// makes them the only places where a short phone removes room that nothing
  /// can give back, so they are measured against the actual height.
  void screenMatrix(
    String what,
    Widget Function() build, {
    List<Override> overrides = const <Override>[],
  }) {
    for (final Device device in kDevices) {
      for (final double scale in kTextScales) {
        testWidgets('$what fits $device at ${scale}x', (
          WidgetTester tester,
        ) async {
          useDevice(tester, device);
          SharedPreferences.setMockInitialValues(<String, Object>{});
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          await tester.pumpWidget(
            ProviderScope(
              overrides: <Override>[
                tasbihPaceProvider.overrideWithValue(false),
                prefsProvider.overrideWithValue(PrefsService(prefs)),
                ...overrides,
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: asDevice(
                  device: device,
                  textScale: scale,
                  child: build(),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));

          expect(
            tester.takeException(),
            isNull,
            reason:
                '$what does not fit $device at ${scale}x text — and this '
                'screen has no scroll view, so the overflow is a clip.',
          );
        });
      }
    }
  }

  screenMatrix('tasbih', () => const TasbihScreen());

  screenMatrix(
    'qibla',
    () => const QiblaScreen(),
    overrides: <Override>[
      tasbihPaceProvider.overrideWithValue(false),
      placeProvider.overrideWith(
        (Ref ref) async => const NoorPlace(
          lat: 3.139,
          lng: 101.6869,
          city: 'Kuala Lumpur',
          country: 'Malaysia',
        ),
      ),
      qiblaProvider.overrideWithValue(
        const AsyncValue<QiblaState>.data(
          QiblaState(
            qiblaBearing: 292.5,
            heading: 41.0,
            hasSensor: true,
            needsCalibration: true,
            distanceKm: 6528,
          ),
        ),
      ),
    ],
  );

  // Qibla, with its two live dependencies stubbed. placeProvider goes to
  // Firebase and qiblaProvider wants a magnetometer; neither exists in a
  // widget test, and neither has anything to do with whether the compass
  // fits. The values below are Kuala Lumpur — a real bearing and a real
  // distance, so the labels are the length they will really be.
  //
  // needsCalibration is the interesting case rather than the tidy one: it
  // adds a warning line to a screen that does not scroll, which is exactly
  // the combination that runs a short phone out of room.

  /// The crop editor, which does not scroll either — and cannot, because the
  /// circle in the middle of it is the crop.
  ///
  /// Two things are asserted, and the second is the one that matters. An
  /// overflow would be caught by `takeException` as everywhere else; but this
  /// screen can fail without overflowing at all, because the circle is drawn
  /// on a layer of its own over the chrome rather than laid out beside it.
  /// Nothing in the widget tree objects if it slides underneath the heading
  /// or the button — it simply covers them. The reservations in
  /// `AvatarCropScreen.topChrome` and `bottomChrome` are what keep it off
  /// them, and this is the only thing that can say whether those two numbers
  /// still describe the screen they were measured on.
  final Uint8List cropSource = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 1200, height: 900), quality: 80),
  );

  for (final Device device in kDevices) {
    for (final double scale in kTextScales) {
      testWidgets('the crop editor fits $device at ${scale}x', (
        WidgetTester tester,
      ) async {
        useDevice(tester, device);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: asDevice(
              device: device,
              textScale: scale,
              child: AvatarCropScreen(source: cropSource),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));

        expect(
          tester.takeException(),
          isNull,
          reason:
              'the crop editor overflows on $device at ${scale}x text, and it '
              'has no scroll view to hide it in.',
        );

        final double diameter = AvatarCrop.diameterFor(
          viewport: device.size,
          safe: device.padding,
          topChrome: AvatarCropScreen.topChrome,
          bottomChrome: AvatarCropScreen.bottomChrome,
          textScale: scale,
        );
        // The circle is centred on the screen, not on the space between the
        // chrome — see AvatarCrop.diameterFor.
        final double top = device.size.height / 2 - diameter / 2;
        final double bottom = device.size.height / 2 + diameter / 2;

        expect(
          top,
          greaterThan(tester.getRect(find.textContaining('Pinch and')).bottom),
          reason:
              'the circle reaches up over the heading on $device at '
              '${scale}x — AvatarCropScreen.topChrome is under-reserving.',
        );
        expect(
          bottom,
          lessThan(tester.getRect(find.byType(PrimaryButton)).top),
          reason:
              'the circle reaches down over the button on $device at '
              '${scale}x — AvatarCropScreen.bottomChrome is under-reserving.',
        );
      });
    }
  }
}
