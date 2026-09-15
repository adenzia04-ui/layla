import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/theme/app_colors.dart';
import 'package:noor/features/home/presentation/widgets/prayer_grid.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/streaks/domain/prayer_day.dart';

import 'test_fonts.dart';

void main() {
  setUpAll(loadNoorFonts);

  testWidgets('prayer grid', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393 * 3, 300 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final DateTime date = DateTime(2026, 8, 21);
    DateTime at(int h, int m) => DateTime(2026, 8, 21, h, m);

    // Asr is running, Fajr confirmed, Dhuhr still owes its photo.
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

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.midnight,
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: PrayerGrid(
              schedule: schedule,
              now: at(17, 10),
              day: const PrayerDay(
                dateId: '2026-08-21',
                records: <PrayerId, PrayerRecord>{
                  PrayerId.fajr: PrayerRecord(status: PrayerStatus.completed),
                  PrayerId.dhuhr: PrayerRecord(
                    status: PrayerStatus.awaitingProof,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(PrayerGrid),
      matchesGoldenFile('goldens/prayer_grid.png'),
    );
  });
}
