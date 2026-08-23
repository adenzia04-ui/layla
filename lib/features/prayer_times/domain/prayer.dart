import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The seven moments Noor tracks. `sunrise` is shown for reference only —
/// it is not a prayer and never counts toward a streak.
enum PrayerId {
  fajr('fajr', 'Fajr', PrayerPalette.fajr, Icons.wb_twilight_rounded),
  sunrise('sunrise', 'Sunrise', PrayerPalette.sunrise, Icons.light_mode_rounded),
  dhuhr('dhuhr', 'Dhuhr', PrayerPalette.dhuhr, Icons.wb_sunny_rounded),
  asr('asr', 'Asr', PrayerPalette.asr, Icons.filter_drama_rounded),
  maghrib('maghrib', 'Maghrib', PrayerPalette.maghrib, Icons.brightness_4_rounded),
  isha('isha', 'Isha', PrayerPalette.isha, Icons.nightlight_round),
  tahajjud('tahajjud', 'Tahajjud', PrayerPalette.tahajjud, Icons.bedtime_rounded);

  const PrayerId(this.key, this.label, this.palette, this.icon);

  /// Stable identifier used in Firestore maps, storage paths and deep links.
  final String key;
  final String label;
  final PrayerPalette palette;
  final IconData icon;

  /// The five that build a streak.
  static const List<PrayerId> obligatory = <PrayerId>[
    PrayerId.fajr,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha,
  ];

  /// The six rows the dashboard lists (the five plus Tahajjud).
  static const List<PrayerId> dashboard = <PrayerId>[
    PrayerId.fajr,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha,
    PrayerId.tahajjud,
  ];

  bool get isObligatory => obligatory.contains(this);
  bool get countsForStreak => isObligatory;

  static PrayerId? fromKey(String? key) {
    for (final PrayerId id in PrayerId.values) {
      if (id.key == key) return id;
    }
    return null;
  }
}

/// One prayer on a given day, with the window it occupies.
@immutable
class PrayerSlot {
  const PrayerSlot({
    required this.id,
    required this.start,
    required this.end,
  });

  final PrayerId id;
  final DateTime start;

  /// When the next prayer begins — the outer bound of this prayer's window.
  final DateTime end;

  bool isActiveAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  Duration timeUntil(DateTime now) => start.difference(now);
  Duration remaining(DateTime now) => end.difference(now);

  // Value equality matters here: providers that recompute every second return
  // the same slot most of the time, and Riverpod skips the rebuild only if
  // the values compare equal.
  @override
  bool operator ==(Object other) =>
      other is PrayerSlot &&
      other.id == id &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, start, end);
}

/// The night window for Tahajjud: the last third of the night, ending at Fajr.
@immutable
class TahajjudWindow {
  const TahajjudWindow({required this.start, required this.end});

  /// Start of the last third of the night.
  final DateTime start;

  /// Fajr — Tahajjud must end before this.
  final DateTime end;

  bool isActiveAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  Duration timeUntil(DateTime now) => start.difference(now);
  Duration remaining(DateTime now) => end.difference(now);
  Duration get length => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is TahajjudWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// A full day of computed times plus the Qibla bearing for the same place.
@immutable
class PrayerSchedule {
  const PrayerSchedule({
    required this.date,
    required this.slots,
    required this.tahajjud,
    required this.qiblaBearing,
    required this.latitude,
    required this.longitude,
  });

  final DateTime date;

  /// Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha — in order.
  final List<PrayerSlot> slots;
  final TahajjudWindow tahajjud;

  /// Degrees clockwise from true north to the Kaaba.
  final double qiblaBearing;
  final double latitude;
  final double longitude;

  PrayerSlot slotFor(PrayerId id) =>
      slots.firstWhere((PrayerSlot s) => s.id == id);

  /// The five prayers only — what the dashboard list and streaks care about.
  List<PrayerSlot> get obligatory =>
      slots.where((PrayerSlot s) => s.id.isObligatory).toList(growable: false);

  /// The prayer whose window contains [now]; null before Fajr.
  PrayerSlot? currentAt(DateTime now) {
    PrayerSlot? found;
    for (final PrayerSlot slot in obligatory) {
      if (!now.isBefore(slot.start)) found = slot;
    }
    if (found == null) return null;
    return found.end.isAfter(now) ? found : found;
  }

  /// The next prayer to come, or null when Isha has already begun (the caller
  /// then asks for tomorrow's Fajr).
  PrayerSlot? nextAt(DateTime now) {
    for (final PrayerSlot slot in obligatory) {
      if (slot.start.isAfter(now)) return slot;
    }
    return null;
  }
}
