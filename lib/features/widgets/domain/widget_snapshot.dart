import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../prayer_times/domain/prayer.dart';

/// One prayer as the widgets and Live Activity need it.
@immutable
class WidgetPrayer {
  const WidgetPrayer({
    required this.key,
    required this.label,
    required this.startsAt,
  });

  final String key;
  final String label;
  final DateTime startsAt;

  Map<String, Object?> toMap() => <String, Object?>{
    'key': key,
    'label': label,
    'epoch': startsAt.millisecondsSinceEpoch ~/ 1000,
  };
}

/// Everything the home-screen widgets and the Live Activity render, computed
/// in Dart and handed to the App Group as one JSON blob.
///
/// The widget extension does no prayer maths of its own — it cannot, since
/// `adhan` is a Dart package and a widget process is not a Flutter engine. It
/// reads this snapshot and formats it. Countdowns tick client-side via
/// SwiftUI's timer text, so a stale snapshot still shows a correct countdown.
@immutable
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.city,
    required this.hijri,
    required this.latitude,
    required this.longitude,
    required this.prayers,
    required this.nextKey,
    required this.nextStartsAt,
    required this.currentKey,
    required this.currentStartedAt,
    required this.streak,
    required this.completedToday,
    required this.totalToday,
    required this.locked,
    required this.lockedPrayerLabel,
    this.confirmed = const <String>{},
    this.tasbihToday = 0,
    this.theme = 'midnight',
  });

  final String city;
  final String hijri;
  final double latitude;
  final double longitude;

  /// The five obligatory prayers, in order.
  final List<WidgetPrayer> prayers;

  final String nextKey;
  final DateTime nextStartsAt;

  /// The prayer whose window is running; empty before Fajr.
  final String currentKey;
  final DateTime currentStartedAt;

  final int streak;
  final int completedToday;
  final int totalToday;

  /// True while apps are blocked and a prayer is unconfirmed.
  final bool locked;
  final String lockedPrayerLabel;

  /// Keys of the prayers confirmed today.
  ///
  /// The counts say how many; the tracker widget has to draw *which*, and a
  /// row of ticks that guessed would be worse than no widget at all.
  final Set<String> confirmed;

  /// Today's tasbih count, for the counter widget.
  final int tasbihToday;

  /// The colour set the widgets draw in — a [WidgetTheme] id.
  final String theme;

  /// How far through the gap between the current and next prayer we are —
  /// what the curved gauge fills.
  double progressAt(DateTime now) {
    final int span = nextStartsAt.difference(currentStartedAt).inSeconds;
    if (span <= 0) return 0;
    final int done = now.difference(currentStartedAt).inSeconds;
    return (done / span).clamp(0, 1);
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'city': city,
    'hijri': hijri,
    'latitude': latitude,
    'longitude': longitude,
    'prayers': prayers.map((WidgetPrayer p) => p.toMap()).toList(),
    'nextKey': nextKey,
    'nextEpoch': nextStartsAt.millisecondsSinceEpoch ~/ 1000,
    'currentKey': currentKey,
    'currentEpoch': currentStartedAt.millisecondsSinceEpoch ~/ 1000,
    'streak': streak,
    'completedToday': completedToday,
    'totalToday': totalToday,
    'locked': locked,
    'lockedPrayerLabel': lockedPrayerLabel,
    'confirmed': confirmed.toList(),
    'tasbihToday': tasbihToday,
    'theme': theme,
    'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  };

  String toJson() => jsonEncode(toMap());

  /// Cheap equality so the publisher only crosses the platform channel when
  /// something a widget would actually draw has changed. Deliberately ignores
  /// `updatedAt` — a new timestamp every second is not a change.
  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.city == city &&
      other.hijri == hijri &&
      other.nextKey == nextKey &&
      other.nextStartsAt == nextStartsAt &&
      other.currentKey == currentKey &&
      other.streak == streak &&
      other.completedToday == completedToday &&
      other.locked == locked &&
      other.lockedPrayerLabel == lockedPrayerLabel &&
      // Riverpod only tells the publisher about a new snapshot when it is
      // unequal to the last one, so anything a widget draws must be in here.
      // The theme was not, and a colour picked in Settings never left the
      // phone's memory.
      other.theme == theme &&
      other.tasbihToday == tasbihToday &&
      other.confirmed.length == confirmed.length &&
      other.confirmed.containsAll(confirmed);

  @override
  int get hashCode => Object.hash(
    city,
    hijri,
    nextKey,
    nextStartsAt,
    currentKey,
    streak,
    completedToday,
    locked,
    lockedPrayerLabel,
    theme,
    tasbihToday,
    confirmed.length,
  );

  static List<WidgetPrayer> prayersFrom(PrayerSchedule schedule) =>
      <WidgetPrayer>[
        for (final PrayerSlot slot in schedule.obligatory)
          WidgetPrayer(
            key: slot.id.key,
            label: slot.id.label,
            startsAt: slot.start,
          ),
      ];
}
