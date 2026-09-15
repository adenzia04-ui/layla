import 'package:flutter/foundation.dart';

import 'dhikr.dart';
import 'quran_passages.dart';

/// A named dhikr from the sunnah with a count the hadith actually gives.
///
/// Every routine here carries its narration and reference, and nothing is
/// listed without one. Where a report gives no number — "la hawla wa la quwwata
/// illa billah" is a treasure of Paradise, but Sahih al-Bukhari 6384 sets no
/// target — it belongs in Manual as a preset, not here. Inventing a count to
/// make it fit this screen would be putting words into the hadith.
/// How the picker groups routines: by when you would reach for them.
enum RoutineGroup {
  quick('Quick dhikr'),
  morning('Morning'),
  evening('Evening'),
  prayer('After prayer'),
  sleep('Before sleep');

  const RoutineGroup(this.label);
  final String label;
}

@immutable
class SunnahRoutine {
  const SunnahRoutine({
    required this.id,
    required this.name,
    required this.occasion,
    required this.stages,
    required this.narration,
    required this.reference,
    required this.groups,
    required this.virtue,
    this.grading,
  });

  /// Stored in preferences, so it must not change once shipped.
  final String id;

  final String name;

  /// When it is said — shown under the name in the picker.
  final String occasion;

  /// One entry per dhikr, in the order the narration gives them. More than one
  /// means the counter hands over on its own at each boundary.
  final List<Dhikr> stages;

  final String narration;
  final String reference;

  /// A set, not one value. Several of these are said morning *and* evening,
  /// and filing such a routine under a single heading would leave the other
  /// section looking empty when it is not.
  final Set<RoutineGroup> groups;

  /// Why it is said, in one line — the promise the narration makes.
  final String virtue;

  /// Set only where a routine is not in Bukhari or Muslim. Shown in the app,
  /// because presenting a hasan report as though it stood alongside the two
  /// Sahihs would be misleading by omission.
  final String? grading;

  int get total =>
      stages.fold<int>(0, (int sum, Dhikr d) => sum + d.defaultTarget);

  bool get hasStages => stages.length > 1;

  static const SunnahRoutine afterPrayer = SunnahRoutine(
    id: 'after_prayer',
    groups: <RoutineGroup>{RoutineGroup.prayer},
    virtue: 'The sayer of these will never be disappointed',
    name: 'After prayer',
    occasion: 'After every obligatory prayer',
    stages: <Dhikr>[Dhikr.subhanAllah, Dhikr.alhamdulillah, Dhikr.allahuAkbar],
    narration:
        'There are certain words, the repeaters of which at the end of '
        'every prayer will never be caused disappointment: thirty-three '
        'tasbih, thirty-three tahmid and thirty-four takbir.',
    reference: "Ka'b ibn 'Ujrah — Sahih Muslim 596a",
  );

  /// Taught to Fatimah when she asked for a servant to spare her hands.
  ///
  /// Note the order: this narration leads with thirty-four takbir rather than
  /// closing on it, which is the reverse of [afterPrayer]. Same hundred,
  /// different sequence — do not "tidy" one into the other.
  static const SunnahRoutine beforeSleep = SunnahRoutine(
    id: 'before_sleep',
    groups: <RoutineGroup>{RoutineGroup.sleep},
    virtue: 'Better for you than a servant',
    name: 'Before sleep',
    occasion: 'On going to bed — the tasbih of Fatimah',
    stages: <Dhikr>[Dhikr.allahuAkbar, Dhikr.subhanAllah, Dhikr.alhamdulillah],
    narration:
        'When you go to bed, say "Allahu akbar" thirty-four times, '
        '"subhan Allah" thirty-three times and "al-hamdu lillah" thirty-three '
        'times. That is better for you than a servant.',
    reference: 'Ali ibn Abi Talib — Sahih al-Bukhari 3113, Sahih Muslim 2727',
  );

  static const SunnahRoutine tasbihHundred = SunnahRoutine(
    id: 'tasbih_100',
    groups: <RoutineGroup>{RoutineGroup.quick},
    virtue: 'Sins forgiven, though they be like the foam of the sea',
    name: 'SubhanAllahi wa bihamdihi',
    occasion: 'A hundred times a day',
    stages: <Dhikr>[Dhikr.subhanAllahiWaBihamdihi],
    narration:
        'Whoever says "SubhanAllahi wa bihamdihi" a hundred times a day '
        'will have his sins forgiven, though they be like the foam of the sea.',
    reference: 'Abu Hurairah — Sahih al-Bukhari 6405',
  );

  static const SunnahRoutine tahlilHundred = SunnahRoutine(
    id: 'tahlil_100',
    groups: <RoutineGroup>{RoutineGroup.quick},
    virtue: 'Ten slaves freed, a hundred good deeds, a shield from Satan',
    name: 'Tahlil',
    occasion: 'A hundred times a day',
    stages: <Dhikr>[Dhikr.tahlil],
    narration:
        'Whoever says it a hundred times a day has the reward of '
        'freeing ten slaves, a hundred good deeds are written for him, a '
        'hundred sins are erased, and it is a shield from Satan for him that '
        'day until nightfall.',
    reference: 'Abu Hurairah — Sahih al-Bukhari 6403',
  );

  static const SunnahRoutine istighfarHundred = SunnahRoutine(
    id: 'istighfar_100',
    groups: <RoutineGroup>{RoutineGroup.quick},
    virtue: 'The Prophet \u{FDFA} sought forgiveness a hundred times a day',
    name: 'Istighfar',
    occasion: 'A hundred times a day',
    stages: <Dhikr>[Dhikr.astaghfirullah],
    narration:
        'O people, turn to Allah in repentance. I seek His forgiveness '
        'a hundred times a day.',
    reference: 'Al-Agharr al-Muzani — Sahih Muslim 2702b',
  );

  static const SunnahRoutine juwayriyah = SunnahRoutine(
    id: 'juwayriyah_3',
    groups: <RoutineGroup>{RoutineGroup.morning},
    virtue: 'Outweighs a whole morning of dhikr',
    name: "Juwayriyah's tasbih",
    occasion: 'Three times in the morning',
    stages: <Dhikr>[Dhikr.juwayriyah],
    narration:
        'I have said four words three times since leaving you which, if '
        'weighed against all you have said since morning, would outweigh it.',
    reference: 'Juwayriyah bint al-Harith — Sahih Muslim 2726a',
  );

  /// Graded hasan rather than sahih — sound and widely acted upon, but a step
  /// below the rest of this list, which the app says out loud.
  static const SunnahRoutine raditu = SunnahRoutine(
    id: 'raditu_3',
    groups: <RoutineGroup>{RoutineGroup.morning, RoutineGroup.evening},
    virtue: 'Allah will please him on the Day of Resurrection',
    name: 'Raditu billahi rabban',
    occasion: 'Three times, morning and evening',
    stages: <Dhikr>[Dhikr.raditu],
    narration:
        'No servant says, morning and evening, "I am pleased with '
        'Allah as Lord, with Islam as religion and with Muhammad as Prophet" '
        'three times, but it will be a right upon Allah to please him on the '
        'Day of Resurrection.',
    reference:
        'Abu Sa\'id al-Khudri — Sunan Abi Dawud, Tirmidhi; '
        'Hisn al-Muslim 87',
    grading: 'Hasan',
  );

  /// Distinct from [tasbihHundred]. Sahih al-Bukhari 6405 promises forgiveness
  /// for a hundred a day; Sahih Muslim 2692 ties a different promise to a
  /// hundred in the morning and a hundred in the evening. Same words, two
  /// reports, two rewards — kept apart rather than merged into one card.
  static const SunnahRoutine tasbihMorningEvening = SunnahRoutine(
    id: 'tasbih_morning_evening',
    groups: <RoutineGroup>{RoutineGroup.morning, RoutineGroup.evening},
    virtue: 'None will come with better on the Day of Resurrection',
    name: 'Morning & evening tasbih',
    occasion: 'A hundred, morning and evening',
    stages: <Dhikr>[Dhikr.subhanAllahiWaBihamdihi],
    narration:
        'Whoever says "SubhanAllahi wa bihamdihi" a hundred times in '
        'the morning and a hundred times in the evening, none will come on the '
        'Day of Resurrection with anything better than what he has brought, '
        'except one who said the same or more.',
    reference: 'Abu Hurairah — Sahih Muslim 2692',
  );

  /// Qur'an, then the tasbih of Fatimah — seven stages that hand over as each
  /// finishes.
  ///
  /// The three quls are laid out three-each in sequence, which is how the app
  /// counts them. Aisha's narration describes the Prophet \u{FDFA} reciting all
  /// three, blowing into his cupped hands and wiping over himself, and doing
  /// that whole round three times. The totals are the same either way; the
  /// order within them is not, and the description says so rather than
  /// implying the flat sequence is what was narrated.
  static const SunnahRoutine beforeSleepProtection = SunnahRoutine(
    id: 'before_sleep_protection',
    groups: <RoutineGroup>{RoutineGroup.sleep},
    virtue: 'A guardian through the night, and no devil comes near',
    name: 'Before sleep — protection',
    occasion: "End the day with Qur'an, dhikr and protection",
    stages: <Dhikr>[
      QuranPassages.ayatAlKursi,
      QuranPassages.ikhlas,
      QuranPassages.falaq,
      QuranPassages.nas,
      Dhikr.subhanAllah,
      Dhikr.alhamdulillah,
      Dhikr.allahuAkbar,
    ],
    narration:
        'Whoever recites Ayat al-Kursi when he lies down will have a '
        'guardian from Allah, and no devil will come near him until morning. '
        'The Prophet \u{FDFA} would also recite al-Ikhlas, al-Falaq and an-Nas '
        'into his cupped hands each night, three times over, and the tasbih of '
        'Fatimah is said on going to bed.',
    reference: 'Sahih al-Bukhari 2311, 5017 and 3113; Sahih Muslim 2727',
  );

  static const List<SunnahRoutine> all = <SunnahRoutine>[
    afterPrayer,
    beforeSleep,
    beforeSleepProtection,
    tasbihHundred,
    tahlilHundred,
    istighfarHundred,
    juwayriyah,
    raditu,
    tasbihMorningEvening,
  ];

  static List<SunnahRoutine> inGroup(RoutineGroup group) =>
      all.where((SunnahRoutine r) => r.groups.contains(group)).toList();

  static SunnahRoutine byId(String id) => all.firstWhere(
    (SunnahRoutine r) => r.id == id,
    orElse: () => afterPrayer,
  );
}
