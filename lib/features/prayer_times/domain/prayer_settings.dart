import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter/foundation.dart';

import 'prayer.dart';

/// The calculation methods Noor exposes. Kept to the widely-used set rather
/// than every option `adhan` supports, so the settings screen stays readable.
enum CalcMethod {
  muslimWorldLeague(
    'muslim_world_league',
    'Muslim World League',
    'Fajr 18° · Isha 17° — a common global default',
  ),
  karachi(
    'karachi',
    'University of Islamic Sciences, Karachi',
    'Fajr 18° · Isha 18° — South Asia',
  ),
  ummAlQura(
    'umm_al_qura',
    'Umm al-Qura, Makkah',
    'Fajr 18.5° · Isha 90 min after Maghrib — Saudi Arabia',
  ),
  egyptian(
    'egyptian',
    'Egyptian General Authority',
    'Fajr 19.5° · Isha 17.5° — Egypt, Africa',
  ),
  northAmerica(
    'north_america',
    'ISNA (North America)',
    'Fajr 15° · Isha 15° — North America',
  ),
  dubai('dubai', 'Dubai', 'Fajr 18.2° · Isha 18.2° — UAE'),
  qatar('qatar', 'Qatar', 'Fajr 18° · Isha 90 min after Maghrib'),
  kuwait('kuwait', 'Kuwait', 'Fajr 18° · Isha 17.5°'),
  singapore('singapore', 'Singapore', 'Fajr 20° · Isha 18° — Southeast Asia'),
  turkey('turkey', 'Diyanet (Turkey)', 'Fajr 18° · Isha 17°'),
  moonsighting(
    'moon_sighting_committee',
    'Moonsighting Committee',
    'Seasonal adjustment — higher latitudes',
  );

  const CalcMethod(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  adhan.CalculationParameters get parameters => switch (this) {
    CalcMethod.muslimWorldLeague =>
      adhan.CalculationMethod.muslim_world_league.getParameters(),
    CalcMethod.karachi => adhan.CalculationMethod.karachi.getParameters(),
    CalcMethod.ummAlQura => adhan.CalculationMethod.umm_al_qura.getParameters(),
    CalcMethod.egyptian => adhan.CalculationMethod.egyptian.getParameters(),
    CalcMethod.northAmerica =>
      adhan.CalculationMethod.north_america.getParameters(),
    CalcMethod.dubai => adhan.CalculationMethod.dubai.getParameters(),
    CalcMethod.qatar => adhan.CalculationMethod.qatar.getParameters(),
    CalcMethod.kuwait => adhan.CalculationMethod.kuwait.getParameters(),
    CalcMethod.singapore => adhan.CalculationMethod.singapore.getParameters(),
    CalcMethod.turkey => adhan.CalculationMethod.turkey.getParameters(),
    CalcMethod.moonsighting =>
      adhan.CalculationMethod.moon_sighting_committee.getParameters(),
  };

  static CalcMethod fromKey(String? key) => CalcMethod.values.firstWhere(
    (CalcMethod m) => m.key == key,
    orElse: () => CalcMethod.muslimWorldLeague,
  );
}

/// Asr calculation: Shafi/Maliki/Hanbali use one shadow length, Hanafi two.
enum MadhabOption {
  shafi(
    'shafi',
    'Shafi, Maliki, Hanbali',
    'Asr when a shadow equals its object',
  ),
  hanafi('hanafi', 'Hanafi', 'Asr when a shadow is twice its object');

  const MadhabOption(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  adhan.Madhab get madhab =>
      this == MadhabOption.hanafi ? adhan.Madhab.hanafi : adhan.Madhab.shafi;

  static MadhabOption fromKey(String? key) => MadhabOption.values.firstWhere(
    (MadhabOption m) => m.key == key,
    orElse: () => MadhabOption.shafi,
  );
}

/// What the shield covers when a prayer window opens.
enum BlockScope {
  /// Every app on the phone. iOS still lets Phone, Messages and Settings
  /// through — Apple will not allow an app to shield those, and you would not
  /// want it to.
  everything('everything', 'Everything', 'Every app on the phone'),

  /// Only the apps the user picked in Apple's own picker.
  specificApps('specific_apps', 'Specific apps', 'Tap to pick apps'),

  /// Whole categories — Social, Games, Entertainment.
  categories('categories', 'Categories', 'Block by category');

  const BlockScope(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  /// True when the user has to choose something in Apple's picker first.
  bool get needsSelection => this != BlockScope.everything;

  static BlockScope fromKey(String? key) => BlockScope.values.firstWhere(
    (BlockScope s) => s.key == key,
    orElse: () => BlockScope.everything,
  );
}

/// Everything that changes the computed times, plus the per-prayer toggles.
@immutable
class PrayerSettings {
  const PrayerSettings({
    this.method = CalcMethod.muslimWorldLeague,
    this.madhab = MadhabOption.shafi,
    this.adjustments = const <String, int>{},
    this.notifications = const <String, bool>{},
    this.lockEnabled = true,
    this.tahajjudVisible = false,
    this.use24hClock = false,
    this.blockScope = BlockScope.everything,
    this.blocking = const <String, bool>{},
    this.remindBefore = true,
    this.beforeMinutes = 10,
    this.remindAfter = true,
    this.afterMinutes = 30,
  });

  final CalcMethod method;
  final MadhabOption madhab;

  /// Manual offsets in minutes, keyed by [PrayerId.key].
  final Map<String, int> adjustments;

  /// Per-prayer reminder toggles, keyed by [PrayerId.key]. Missing = on.
  final Map<String, bool> notifications;

  /// Whether the 30-minute prayer focus session opens automatically.
  final bool lockEnabled;

  /// Opt-in for appearing on the Tahajjud live map.
  final bool tahajjudVisible;
  final bool use24hClock;

  /// What the shield covers.
  final BlockScope blockScope;

  /// Which prayers actually block apps, keyed by [PrayerId.key].
  /// Missing = on, so enabling the feature blocks all five by default.
  final Map<String, bool> blocking;

  /// A nudge ahead of the adhan, so the ten minutes before it are not spent
  /// halfway into something else.
  final bool remindBefore;
  final int beforeMinutes;

  /// A second call once the window has been open a while and nothing has been
  /// confirmed. Cancelled the moment the prayer is confirmed — a notification
  /// saying "you still have not prayed Asr" arriving after someone has prayed
  /// it is worse than no notification at all.
  final bool remindAfter;
  final int afterMinutes;

  /// The minute options offered. Fixed rather than free-form: three choices
  /// are decided in a second, a spinner is not.
  static const List<int> beforeChoices = <int>[5, 10, 15];
  static const List<int> afterChoices = <int>[15, 30, 45];

  int adjustmentFor(PrayerId id) => adjustments[id.key] ?? 0;
  bool notifies(PrayerId id) => notifications[id.key] ?? true;

  /// Whether this prayer's window blocks apps.
  bool blocks(PrayerId id) => blocking[id.key] ?? true;

  /// "3 of 5" for the settings header.
  int get blockingCount => PrayerId.obligatory.where(blocks).length;

  PrayerSettings copyWith({
    bool? remindBefore,
    int? beforeMinutes,
    bool? remindAfter,
    int? afterMinutes,
    CalcMethod? method,
    MadhabOption? madhab,
    Map<String, int>? adjustments,
    Map<String, bool>? notifications,
    bool? lockEnabled,
    bool? tahajjudVisible,
    bool? use24hClock,
    BlockScope? blockScope,
    Map<String, bool>? blocking,
  }) => PrayerSettings(
    method: method ?? this.method,
    madhab: madhab ?? this.madhab,
    adjustments: adjustments ?? this.adjustments,
    notifications: notifications ?? this.notifications,
    lockEnabled: lockEnabled ?? this.lockEnabled,
    tahajjudVisible: tahajjudVisible ?? this.tahajjudVisible,
    use24hClock: use24hClock ?? this.use24hClock,
    blockScope: blockScope ?? this.blockScope,
    blocking: blocking ?? this.blocking,
    remindBefore: remindBefore ?? this.remindBefore,
    beforeMinutes: beforeMinutes ?? this.beforeMinutes,
    remindAfter: remindAfter ?? this.remindAfter,
    afterMinutes: afterMinutes ?? this.afterMinutes,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'calculationMethod': method.key,
    'madhab': madhab.key,
    'adjustments': adjustments,
    'notifications': notifications,
    'lockEnabled': lockEnabled,
    'tahajjudVisible': tahajjudVisible,
    'use24hClock': use24hClock,
    'blockScope': blockScope.key,
    'blocking': blocking,
    'remindBefore': remindBefore,
    'beforeMinutes': beforeMinutes,
    'remindAfter': remindAfter,
    'afterMinutes': afterMinutes,
  };

  static int _oneOf(Object? raw, List<int> allowed, int fallback) {
    final int? v = (raw as num?)?.toInt();
    return v != null && allowed.contains(v) ? v : fallback;
  }

  factory PrayerSettings.fromMap(Map<String, Object?>? map) {
    if (map == null) return const PrayerSettings();
    return PrayerSettings(
      method: CalcMethod.fromKey(map['calculationMethod'] as String?),
      madhab: MadhabOption.fromKey(map['madhab'] as String?),
      adjustments: <String, int>{
        for (final MapEntry<String, Object?> e
            in (map['adjustments'] as Map<String, Object?>? ??
                    <String, Object?>{})
                .entries)
          e.key: (e.value as num?)?.toInt() ?? 0,
      },
      notifications: <String, bool>{
        for (final MapEntry<String, Object?> e
            in (map['notifications'] as Map<String, Object?>? ??
                    <String, Object?>{})
                .entries)
          e.key: e.value as bool? ?? true,
      },
      lockEnabled: map['lockEnabled'] as bool? ?? true,
      tahajjudVisible: map['tahajjudVisible'] as bool? ?? false,
      use24hClock: map['use24hClock'] as bool? ?? false,
      blockScope: BlockScope.fromKey(map['blockScope'] as String?),
      blocking: <String, bool>{
        for (final MapEntry<String, Object?> e
            in (map['blocking'] as Map<String, Object?>? ?? <String, Object?>{})
                .entries)
          e.key: e.value as bool? ?? true,
      },
      remindBefore: map['remindBefore'] as bool? ?? true,
      // Clamped to the offered choices. A value from an older build, or a
      // hand-edited document, must not schedule a reminder at some hour the
      // settings screen cannot show or undo.
      beforeMinutes: _oneOf(map['beforeMinutes'], beforeChoices, 10),
      remindAfter: map['remindAfter'] as bool? ?? true,
      afterMinutes: _oneOf(map['afterMinutes'], afterChoices, 30),
    );
  }
}
