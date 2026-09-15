import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/prayer_times/data/prayer_engine.dart';
import 'package:noor/features/prayer_times/domain/prayer.dart';
import 'package:noor/features/prayer_times/domain/prayer_settings.dart';

void main() {
  const PrayerEngine engine = PrayerEngine();

  // Kuala Lumpur, a low-latitude city where all six times are well defined.
  const double lat = 3.1390;
  const double lng = 101.6869;
  final DateTime date = DateTime(2026, 8, 20);

  PrayerSchedule build({PrayerSettings settings = const PrayerSettings()}) =>
      engine.scheduleFor(
        latitude: lat,
        longitude: lng,
        date: date,
        settings: settings,
      );

  group('PrayerSchedule', () {
    test('produces all six times in chronological order', () {
      final PrayerSchedule schedule = build();
      expect(schedule.slots.length, 6);

      for (int i = 1; i < schedule.slots.length; i++) {
        expect(
          schedule.slots[i].start.isAfter(schedule.slots[i - 1].start),
          isTrue,
          reason:
              '${schedule.slots[i].id.label} must come after '
              '${schedule.slots[i - 1].id.label}',
        );
      }
    });

    test("each slot ends where the next begins, and Isha runs to tomorrow's "
        'Fajr', () {
      final PrayerSchedule schedule = build();
      for (int i = 0; i < schedule.slots.length - 1; i++) {
        expect(schedule.slots[i].end, schedule.slots[i + 1].start);
      }
      final PrayerSlot isha = schedule.slotFor(PrayerId.isha);
      expect(isha.end.isAfter(isha.start), isTrue);
      expect(isha.end.difference(isha.start).inHours, lessThan(16));
    });

    test('only the five obligatory prayers count for streaks', () {
      expect(build().obligatory.length, 5);
      expect(PrayerId.sunrise.countsForStreak, isFalse);
      expect(PrayerId.tahajjud.countsForStreak, isFalse);
    });

    test('manual adjustments shift a prayer by the given minutes', () {
      final PrayerSchedule plain = build();
      final PrayerSchedule shifted = build(
        settings: const PrayerSettings(adjustments: <String, int>{'fajr': 7}),
      );
      expect(
        shifted
            .slotFor(PrayerId.fajr)
            .start
            .difference(plain.slotFor(PrayerId.fajr).start),
        const Duration(minutes: 7),
      );
    });

    test('Hanafi Asr falls later than Shafi Asr', () {
      final DateTime shafi = build().slotFor(PrayerId.asr).start;
      final DateTime hanafi = build(
        settings: const PrayerSettings(madhab: MadhabOption.hanafi),
      ).slotFor(PrayerId.asr).start;
      expect(hanafi.isAfter(shafi), isTrue);
    });

    test('currentAt is null before Fajr and returns Isha late at night', () {
      final PrayerSchedule schedule = build();
      final DateTime beforeFajr = schedule
          .slotFor(PrayerId.fajr)
          .start
          .subtract(const Duration(minutes: 10));
      expect(schedule.currentAt(beforeFajr), isNull);

      final DateTime afterIsha = schedule
          .slotFor(PrayerId.isha)
          .start
          .add(const Duration(minutes: 30));
      expect(schedule.currentAt(afterIsha)?.id, PrayerId.isha);
      expect(schedule.nextAt(afterIsha), isNull);
    });
  });

  group('Tahajjud window', () {
    test('sits inside the night and ends at Fajr', () {
      final PrayerSchedule schedule = build();
      final TahajjudWindow window = schedule.tahajjud;

      expect(window.end.isAfter(window.start), isTrue);
      expect(window.length.inMinutes, greaterThan(60));
      expect(window.length.inHours, lessThan(6));
    });

    test('at 3 a.m. returns the window in progress, not tomorrow night', () {
      // Someone opening Noor at 3 a.m. is inside the night that started
      // yesterday evening — the engine must not tell them Tahajjud is 20
      // hours away.
      final DateTime threeAm = DateTime(2026, 8, 20, 3);
      final TahajjudWindow window = engine.tahajjudWindow(
        latitude: lat,
        longitude: lng,
        reference: threeAm,
      );
      expect(window.isActiveAt(threeAm), isTrue);
    });

    test('at midday returns the window that opens tonight', () {
      final DateTime midday = DateTime(2026, 8, 20, 12);
      final TahajjudWindow window = engine.tahajjudWindow(
        latitude: lat,
        longitude: lng,
        reference: midday,
      );
      expect(window.isActiveAt(midday), isFalse);
      expect(window.start.isAfter(midday), isTrue);
    });
  });

  group('Qibla', () {
    test('points roughly west-north-west from Kuala Lumpur', () {
      final double bearing = engine.qiblaBearing(lat, lng);
      expect(bearing, greaterThan(280));
      expect(bearing, lessThan(300));
    });

    test('points north-east from Cape Town', () {
      final double bearing = engine.qiblaBearing(-33.9249, 18.4241);
      expect(bearing, greaterThan(10));
      expect(bearing, lessThan(40));
    });
  });
}
