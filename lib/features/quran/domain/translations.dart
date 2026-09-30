import 'package:flutter/foundation.dart';

/// An English rendering of the Qur'an bundled with the app.
///
/// Five, all of them the ones actually on the shelves and in the mosques:
/// the reader shows any mix, so a reading can be checked against a second
/// voice without leaving the ayah.
@immutable
class Translation {
  const Translation({
    required this.id,
    required this.name,
    required this.author,
    required this.note,
  });

  /// quran.com's resource id, which is how the text is keyed in the data.
  final String id;
  final String name;
  final String author;
  final String note;
}

const List<Translation> translations = <Translation>[
  Translation(
    id: '20',
    name: 'Saheeh International',
    author: 'Saheeh International',
    note: 'Plain, careful modern English — the default',
  ),
  Translation(
    id: '203',
    name: 'Hilali & Khan',
    author: 'Al-Hilali & Muhsin Khan',
    note: 'The Madinah edition, with the salaf’s explanations in brackets',
  ),
  Translation(
    id: '19',
    name: 'Pickthall',
    author: 'Marmaduke Pickthall',
    note: 'The classic 1930 English, slightly formal',
  ),
  Translation(
    id: '22',
    name: 'Yusuf Ali',
    author: 'Abdullah Yusuf Ali',
    note: 'The most printed English translation',
  ),
  Translation(
    id: '85',
    name: 'Abdel Haleem',
    author: 'M. A. S. Abdel Haleem',
    note: 'Oxford — reads like modern prose',
  ),
];

Translation translationById(String id) => translations.firstWhere(
  (Translation t) => t.id == id,
  orElse: () => translations.first,
);
