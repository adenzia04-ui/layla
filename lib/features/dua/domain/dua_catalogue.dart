import 'package:flutter/material.dart';

/// The Dua Library's structure, taken from the table of contents of
/// *Fortress of the Muslim* (Sa'id 'Ali Wahf al-Qahtani, revised English–Arabic
/// edition, Dakwah Corner Bookstore).
///
/// Titles and section numbers are the book's own. Nothing here is invented:
/// where the book's OCR was ambiguous the wording follows the printed contents
/// page, and the section numbers let every entry be checked against it.
///
/// The supplications themselves are shown as images of the printed pages
/// rather than re-typed text. The supplied PDF is a scan whose Arabic layer did
/// not survive OCR — zero Arabic characters across all 190 pages — so typing it
/// out would have meant writing scripture from memory. Showing the page instead
/// keeps the Arabic exactly as the book sets it.
@immutable
class DuaSection {
  const DuaSection({
    required this.number,
    required this.title,
    required this.page,
    this.subtitle,
  });

  /// The section's number in the book, so any entry can be verified.
  final int number;
  final String title;

  /// Printed page in the source edition.
  final int page;
  final String? subtitle;

  /// Every section resolves to real pages of the book, so all of them open.
  bool get hasText => true;
}

@immutable
class DuaCategory {
  const DuaCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.sections,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<DuaSection> sections;

  int get count => sections.length;
}

/// Prayer, separated by position exactly as the book separates it — sections
/// 16 to 26, in order.
const List<DuaSection> _prayer = <DuaSection>[
  DuaSection(
    number: 16,
    title: 'Beginning of Prayer',
    subtitle: 'Said immediately after the first takbir',
    page: 24,
  ),
  DuaSection(
    number: 17,
    title: 'Ruku‘',
    subtitle: 'Invocations during bowing',
    page: 31,
  ),
  DuaSection(
    number: 18,
    title: 'Rising from Ruku‘',
    subtitle: 'Invocations when rising from bowing',
    page: 33,
  ),
  DuaSection(
    number: 19,
    title: 'Sujud',
    subtitle: 'Invocations during prostration',
    page: 34,
  ),
  DuaSection(
    number: 20,
    title: 'Between Two Sujud',
    subtitle: 'Sitting between the two prostrations',
    page: 37,
  ),
  DuaSection(
    number: 21,
    title: 'Sujud al-Tilawah',
    subtitle: 'Prostration for recitation of the Qur’an',
    page: 38,
  ),
  DuaSection(
    number: 22,
    title: 'Tashahhud',
    subtitle: 'The sitting in prayer',
    page: 39,
  ),
  DuaSection(
    number: 23,
    title: 'Salawat',
    subtitle: 'Blessings on the Prophet ﷺ after the tashahhud',
    page: 40,
  ),
  DuaSection(
    number: 24,
    title: 'Before Ending Prayer',
    subtitle: 'After the final tashahhud, before the salam',
    page: 41,
  ),
  DuaSection(
    number: 25,
    title: 'After Salah',
    subtitle: 'What to say after completing the prayer',
    page: 48,
  ),
  DuaSection(
    number: 26,
    title: 'Istikharah',
    subtitle: 'Seeking Allah’s counsel',
    page: 55,
  ),
];

const List<DuaCategory> duaCategories = <DuaCategory>[
  DuaCategory(
    id: 'prayer',
    title: 'Prayer',
    description: 'Duas recited throughout salah',
    icon: Icons.mosque_rounded,
    sections: _prayer,
  ),
  DuaCategory(
    id: 'morning-evening',
    title: 'Morning & Evening',
    description: 'Daily remembrance and supplications',
    icon: Icons.wb_twilight_rounded,
    sections: <DuaSection>[
      DuaSection(
        number: 27,
        title: 'Morning Adhkar',
        subtitle: 'Words of remembrance for the morning',
        page: 57,
      ),
      DuaSection(
        number: 27,
        title: 'Evening Adhkar',
        subtitle: 'Words of remembrance for the evening',
        page: 57,
      ),
    ],
  ),
  DuaCategory(
    id: 'sleep',
    title: 'Sleep',
    description: 'Duas before sleeping and during the night',
    icon: Icons.nightlight_round,
    sections: <DuaSection>[
      DuaSection(number: 28, title: 'Before Sleeping', page: 77),
      DuaSection(
        number: 29,
        title: 'Stirring During the Night',
        page: 88,
      ),
      DuaSection(
        number: 30,
        title: 'Fear of Sleeping or Loneliness',
        page: 88,
      ),
      DuaSection(number: 31, title: 'Bad Dream or Nightmare', page: 89),
    ],
  ),
  DuaCategory(
    id: 'daily-life',
    title: 'Daily Life',
    description: 'Duas for everyday situations',
    icon: Icons.wb_sunny_rounded,
    sections: <DuaSection>[
      DuaSection(number: 2, title: 'Waking Up', page: 10),
      DuaSection(number: 3, title: 'Getting Dressed', page: 12),
      DuaSection(number: 4, title: 'Putting on New Clothes', page: 12),
      DuaSection(number: 6, title: 'Undressing', page: 14),
      DuaSection(number: 7, title: 'Entering the Bathroom', page: 14),
      DuaSection(number: 8, title: 'Leaving the Bathroom', page: 15),
      DuaSection(number: 9, title: 'Before Ablution', page: 15),
      DuaSection(number: 10, title: 'Completing Ablution', page: 16),
      DuaSection(number: 11, title: 'Leaving Home', page: 17),
      DuaSection(number: 12, title: 'Entering Home', page: 18),
      DuaSection(number: 13, title: 'Going to the Mosque', page: 19),
      DuaSection(number: 14, title: 'Entering the Mosque', page: 20),
      DuaSection(number: 15, title: 'Leaving the Mosque', page: 21),
    ],
  ),
  DuaCategory(
    id: 'protection',
    title: 'Protection',
    description: 'Supplications for protection and difficulties',
    icon: Icons.shield_moon_rounded,
    sections: <DuaSection>[
      DuaSection(number: 34, title: 'Worry and Grief', page: 93),
      DuaSection(number: 35, title: 'Anguish', page: 94),
      DuaSection(
        number: 36,
        title: 'Meeting an Adversary or Ruler',
        page: 96,
      ),
      DuaSection(number: 37, title: 'Oppression of Rulers', page: 97),
      DuaSection(number: 38, title: 'Against an Enemy', page: 99),
      DuaSection(number: 39, title: 'Fear of People’s Harm', page: 100),
      DuaSection(number: 40, title: 'Doubt in Faith', page: 100),
      DuaSection(number: 41, title: 'Settling a Debt', page: 101),
      DuaSection(
        number: 42,
        title: 'Distractions of Satan in Prayer',
        page: 102,
      ),
      DuaSection(number: 43, title: 'When Something Is Difficult', page: 103),
      DuaSection(number: 44, title: 'After Committing a Sin', page: 103),
      DuaSection(number: 45, title: 'Against the Devil’s Promptings', page: 104),
      DuaSection(number: 46, title: 'When Something You Dislike Happens', page: 105),
    ],
  ),
  DuaCategory(
    id: 'travel',
    title: 'Travel',
    description: 'Duas related to travelling',
    icon: Icons.explore_rounded,
    sections: <DuaSection>[
      DuaSection(number: 95, title: 'Riding a Vehicle or Animal', page: 139),
      DuaSection(number: 96, title: 'Travelling', page: 140),
      DuaSection(number: 97, title: 'Entering a Town or City', page: 142),
      DuaSection(number: 98, title: 'Entering a Market', page: 143),
      DuaSection(number: 99, title: 'When Your Vehicle Fails', page: 143),
      DuaSection(
        number: 100,
        title: 'For Those You Leave Behind',
        page: 144,
      ),
      DuaSection(
        number: 101,
        title: 'The Resident’s Dua for the Traveller',
        page: 144,
      ),
      DuaSection(
        number: 102,
        title: 'Glorifying Allah on the Journey',
        page: 145,
      ),
      DuaSection(number: 103, title: 'The Traveller at Dawn', page: 146),
      DuaSection(number: 104, title: 'During a Layover', page: 146),
      DuaSection(number: 105, title: 'Returning from a Journey', page: 147),
    ],
  ),
  DuaCategory(
    id: 'food-drink',
    title: 'Food & Drink',
    description: 'Supplications related to eating and drinking',
    icon: Icons.restaurant_rounded,
    sections: <DuaSection>[
      DuaSection(number: 68, title: 'Breaking the Fast', page: 124),
      DuaSection(number: 69, title: 'Before Eating', page: 124),
      DuaSection(number: 70, title: 'After Eating', page: 126),
      DuaSection(number: 71, title: 'A Guest’s Dua for the Host', page: 127),
      DuaSection(number: 72, title: 'For Someone Who Offers Drink', page: 127),
      DuaSection(
        number: 73,
        title: 'For the Family Who Invite You to Break Your Fast',
        page: 128,
      ),
      DuaSection(
        number: 74,
        title: 'Declining Food While Fasting',
        page: 128,
      ),
      DuaSection(
        number: 75,
        title: 'When Someone Is Rude While You Fast',
        page: 129,
      ),
      DuaSection(number: 76, title: 'Seeing the First Dates', page: 129),
    ],
  ),
  DuaCategory(
    id: 'family-people',
    title: 'Family & People',
    description: 'Duas concerning family, children and others',
    icon: Icons.groups_rounded,
    sections: <DuaSection>[
      DuaSection(number: 47, title: 'Congratulating New Parents', page: 105),
      DuaSection(number: 48, title: 'Protection for Children', page: 106),
      DuaSection(number: 49, title: 'Visiting the Sick', page: 107),
      DuaSection(number: 51, title: 'The Terminally Ill', page: 108),
      DuaSection(number: 53, title: 'When Tragedy Strikes', page: 110),
      DuaSection(number: 55, title: 'The Funeral Prayer', page: 111),
      DuaSection(number: 57, title: 'For the Bereaved', page: 116),
      DuaSection(number: 60, title: 'Visiting Graves', page: 118),
      DuaSection(number: 77, title: 'Sneezing', page: 130),
      DuaSection(number: 79, title: 'For the Groom', page: 131),
      DuaSection(number: 82, title: 'Against Anger', page: 133),
      DuaSection(number: 84, title: 'Sitting in a Gathering', page: 134),
      DuaSection(number: 87, title: 'For Someone Who Does Good to You', page: 135),
      DuaSection(number: 108, title: 'Spreading the Salam', page: 150),
    ],
  ),
];
