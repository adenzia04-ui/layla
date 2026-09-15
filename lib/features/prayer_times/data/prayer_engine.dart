import 'package:adhan/adhan.dart' as adhan;

import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

/// Turns a position + settings into a [PrayerSchedule].
///
/// Pure and synchronous — no I/O, no Firebase — so it is trivially testable
/// and can be recomputed on every tick without cost.
class PrayerEngine {
  const PrayerEngine();

  /// A day's prayer times. [date] is interpreted in the device's local zone.
  PrayerSchedule scheduleFor({
    required double latitude,
    required double longitude,
    required DateTime date,
    PrayerSettings settings = const PrayerSettings(),
  }) {
    final adhan.Coordinates coordinates = adhan.Coordinates(
      latitude,
      longitude,
    );

    final Map<PrayerId, DateTime> today = _timesFor(
      coordinates,
      date,
      settings,
    );
    final Map<PrayerId, DateTime> tomorrow = _timesFor(
      coordinates,
      date.add(const Duration(days: 1)),
      settings,
    );

    const List<PrayerId> ordered = <PrayerId>[
      PrayerId.fajr,
      PrayerId.sunrise,
      PrayerId.dhuhr,
      PrayerId.asr,
      PrayerId.maghrib,
      PrayerId.isha,
    ];

    final List<PrayerSlot> slots = <PrayerSlot>[
      for (int i = 0; i < ordered.length; i++)
        PrayerSlot(
          id: ordered[i],
          start: today[ordered[i]]!,
          // Isha runs until the next Fajr; everything else until the next slot.
          end: i + 1 < ordered.length
              ? today[ordered[i + 1]]!
              : tomorrow[PrayerId.fajr]!,
        ),
    ];

    return PrayerSchedule(
      date: DateTime(date.year, date.month, date.day),
      slots: slots,
      tahajjud: tahajjudWindow(
        latitude: latitude,
        longitude: longitude,
        reference: date,
        settings: settings,
      ),
      qiblaBearing: qiblaBearing(latitude, longitude),
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// The Tahajjud window that either contains [reference] or comes next.
  ///
  /// The night straddles midnight, so we test the window that began last night
  /// before falling back to the one that begins tonight — otherwise someone
  /// opening the app at 3 a.m. would be told Tahajjud is 20 hours away.
  TahajjudWindow tahajjudWindow({
    required double latitude,
    required double longitude,
    required DateTime reference,
    PrayerSettings settings = const PrayerSettings(),
  }) {
    final adhan.Coordinates coordinates = adhan.Coordinates(
      latitude,
      longitude,
    );

    final List<TahajjudWindow> candidates = <TahajjudWindow>[
      for (final int offset in <int>[-1, 0, 1])
        _nightWindow(
          coordinates,
          reference.add(Duration(days: offset)),
          settings,
        ),
    ];

    for (final TahajjudWindow window in candidates) {
      if (window.isActiveAt(reference)) return window;
    }
    for (final TahajjudWindow window in candidates) {
      if (window.start.isAfter(reference)) return window;
    }
    return candidates.last;
  }

  TahajjudWindow _nightWindow(
    adhan.Coordinates coordinates,
    DateTime night,
    PrayerSettings settings,
  ) {
    final adhan.PrayerTimes times = _rawTimes(coordinates, night, settings);
    final adhan.SunnahTimes sunnah = adhan.SunnahTimes(times);
    final DateTime start = sunnah.lastThirdOfTheNight.toLocal();
    final DateTime end = _timesFor(
      coordinates,
      night.add(const Duration(days: 1)),
      settings,
    )[PrayerId.fajr]!;
    return TahajjudWindow(start: start, end: end);
  }

  /// Degrees clockwise from true north toward the Kaaba.
  double qiblaBearing(double latitude, double longitude) =>
      adhan.Qibla(adhan.Coordinates(latitude, longitude)).direction;

  // ── internals ─────────────────────────────────────────────────────────

  adhan.PrayerTimes _rawTimes(
    adhan.Coordinates coordinates,
    DateTime date,
    PrayerSettings settings,
  ) {
    final adhan.CalculationParameters params = settings.method.parameters
      ..madhab = settings.madhab.madhab;
    return adhan.PrayerTimes(
      coordinates,
      adhan.DateComponents.from(date),
      params,
    );
  }

  /// Computes the six raw times and applies the user's manual offsets.
  ///
  /// Offsets are applied here rather than through `CalculationParameters`
  /// so there is one code path and the values are easy to reason about.
  Map<PrayerId, DateTime> _timesFor(
    adhan.Coordinates coordinates,
    DateTime date,
    PrayerSettings settings,
  ) {
    final adhan.PrayerTimes t = _rawTimes(coordinates, date, settings);

    DateTime adjust(PrayerId id, DateTime value) =>
        value.toLocal().add(Duration(minutes: settings.adjustmentFor(id)));

    return <PrayerId, DateTime>{
      PrayerId.fajr: adjust(PrayerId.fajr, t.fajr),
      PrayerId.sunrise: adjust(PrayerId.sunrise, t.sunrise),
      PrayerId.dhuhr: adjust(PrayerId.dhuhr, t.dhuhr),
      PrayerId.asr: adjust(PrayerId.asr, t.asr),
      PrayerId.maghrib: adjust(PrayerId.maghrib, t.maghrib),
      PrayerId.isha: adjust(PrayerId.isha, t.isha),
    };
  }
}
