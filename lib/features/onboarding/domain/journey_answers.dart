import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Who is praying, and what they are up against.
///
/// Gathered once, on first run, and kept because almost every screen in the
/// app reads better when it knows the answer. The name turns "Assalamu
/// alaikum" into a greeting; the Fajr answer decides whether Tahajjud leads
/// with an alarm or with a countdown; the phone hours are the whole point of
/// the reflection step.
///
/// Every field is optional on purpose. Someone can back out of the journey at
/// any point and the app has to work with whatever it managed to learn — a
/// half-answered profile must never be worse than no profile at all.
@immutable
class JourneyAnswers {
  const JourneyAnswers({
    this.name = '',
    this.gender,
    this.avatar,
    this.age,
    this.revert,
    this.prayersADay,
    this.strugglesOnTime,
    this.forgetsAfterDelaying,
    this.strugglesWithFajr,
    this.phoneHoursADay,
    this.wantsMatScan,
    this.wantsAppPause,
    this.remindersAllowed,
    this.pledged = false,
  });

  final String name;

  /// 'brother' or 'sister'. Not a free-text field: it selects the avatar set
  /// and the wording of a handful of screens, and nothing else.
  final String? gender;

  /// Key of the chosen avatar — see `JourneyAvatars`.
  final String? avatar;

  final int? age;

  /// True for someone who reverted to Islam. The journey asks because a revert
  /// is far more likely to want the prayer walkthrough surfaced.
  final bool? revert;

  /// How many of the five they manage on an ordinary day. Honest, not
  /// aspirational — the app uses it to pitch a first target it can actually
  /// clear.
  final int? prayersADay;

  final bool? strugglesOnTime;
  final bool? forgetsAfterDelaying;
  final bool? strugglesWithFajr;

  /// Hours a day on the phone, as they estimate it themselves.
  final int? phoneHoursADay;

  final bool? wantsMatScan;

  /// Whether they want their apps shut during a prayer window.
  final bool? wantsAppPause;

  /// Whether iOS granted notifications. Recorded rather than re-queried
  /// because the journey needs to know whether it already asked — the system
  /// prompt only ever appears once, and asking again silently does nothing.
  final bool? remindersAllowed;

  /// Whether they held the pledge button at the end.
  final bool pledged;

  /// Hours a year, from [phoneHoursADay].
  int? get phoneHoursAYear =>
      phoneHoursADay == null ? null : phoneHoursADay! * 365;

  /// Whole days a year. Deliberately floored: a number someone can check on
  /// their own fingers is more persuasive than one they cannot.
  int? get phoneDaysAYear =>
      phoneHoursADay == null ? null : (phoneHoursADay! * 365) ~/ 24;

  /// Years over a lifetime, assuming the habit holds for fifty more.
  ///
  /// The horizon is stated in the copy rather than hidden here, because a
  /// figure this large is only honest if the reader can see the assumption
  /// behind it.
  int? get phoneYearsALifetime =>
      phoneHoursADay == null ? null : (phoneHoursADay! * 365 * 50) ~/ 8760;

  JourneyAnswers copyWith({
    String? name,
    String? gender,
    String? avatar,
    int? age,
    bool? revert,
    int? prayersADay,
    bool? strugglesOnTime,
    bool? forgetsAfterDelaying,
    bool? strugglesWithFajr,
    int? phoneHoursADay,
    bool? wantsMatScan,
    bool? wantsAppPause,
    bool? remindersAllowed,
    bool? pledged,
  }) => JourneyAnswers(
    name: name ?? this.name,
    gender: gender ?? this.gender,
    avatar: avatar ?? this.avatar,
    age: age ?? this.age,
    revert: revert ?? this.revert,
    prayersADay: prayersADay ?? this.prayersADay,
    strugglesOnTime: strugglesOnTime ?? this.strugglesOnTime,
    forgetsAfterDelaying: forgetsAfterDelaying ?? this.forgetsAfterDelaying,
    strugglesWithFajr: strugglesWithFajr ?? this.strugglesWithFajr,
    phoneHoursADay: phoneHoursADay ?? this.phoneHoursADay,
    wantsMatScan: wantsMatScan ?? this.wantsMatScan,
    wantsAppPause: wantsAppPause ?? this.wantsAppPause,
    remindersAllowed: remindersAllowed ?? this.remindersAllowed,
    pledged: pledged ?? this.pledged,
  );

  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'gender': gender,
    'avatar': avatar,
    'age': age,
    'revert': revert,
    'prayersADay': prayersADay,
    'strugglesOnTime': strugglesOnTime,
    'forgetsAfterDelaying': forgetsAfterDelaying,
    'strugglesWithFajr': strugglesWithFajr,
    'phoneHoursADay': phoneHoursADay,
    'wantsMatScan': wantsMatScan,
    'wantsAppPause': wantsAppPause,
    'remindersAllowed': remindersAllowed,
    'pledged': pledged,
  };

  factory JourneyAnswers.fromMap(Map<String, Object?> map) => JourneyAnswers(
    name: map['name'] as String? ?? '',
    gender: map['gender'] as String?,
    avatar: map['avatar'] as String?,
    age: (map['age'] as num?)?.toInt(),
    revert: map['revert'] as bool?,
    prayersADay: (map['prayersADay'] as num?)?.toInt(),
    strugglesOnTime: map['strugglesOnTime'] as bool?,
    forgetsAfterDelaying: map['forgetsAfterDelaying'] as bool?,
    strugglesWithFajr: map['strugglesWithFajr'] as bool?,
    phoneHoursADay: (map['phoneHoursADay'] as num?)?.toInt(),
    wantsMatScan: map['wantsMatScan'] as bool?,
    wantsAppPause: map['wantsAppPause'] as bool?,
    remindersAllowed: map['remindersAllowed'] as bool?,
    pledged: map['pledged'] as bool? ?? false,
  );

  String encode() => jsonEncode(toMap());

  /// Never throws. A profile that fails to parse is a profile that gets asked
  /// again, which is a far smaller problem than an app that will not start.
  static JourneyAnswers decode(String? raw) {
    if (raw == null || raw.isEmpty) return const JourneyAnswers();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return const JourneyAnswers();
      return JourneyAnswers.fromMap(decoded);
    } on Object {
      return const JourneyAnswers();
    }
  }
}

/// The avatars offered alongside the gender question.
///
/// Emoji rather than bundled art: they render at any size, need no asset
/// pipeline, and sidestep the question of whose face is being drawn.
abstract final class JourneyAvatars {
  static const List<({String key, String emoji, String verse, String ref})>
  all = <({String key, String emoji, String verse, String ref})>[
    (
      key: 'palm',
      emoji: '🌴',
      verse: 'And lofty palm trees, with layered fruit',
      ref: 'Surah Qaf 50:10',
    ),
    (
      key: 'mountain',
      emoji: '🏔️',
      verse: 'And the mountains as pegs',
      ref: 'Surah An-Naba 78:7',
    ),
    (
      key: 'sun',
      emoji: '🌞',
      verse: 'By the sun and its brightness',
      ref: 'Surah Ash-Shams 91:1',
    ),
    (
      key: 'moon',
      emoji: '🌙',
      verse: 'And the moon when it follows it',
      ref: 'Surah Ash-Shams 91:2',
    ),
  ];

  static ({String key, String emoji, String verse, String ref})? byKey(
    String? key,
  ) {
    for (final ({String key, String emoji, String verse, String ref}) a
        in all) {
      if (a.key == key) return a;
    }
    return null;
  }
}
