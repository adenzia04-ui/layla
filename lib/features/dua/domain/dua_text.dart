import 'dart:convert';

import 'package:flutter/services.dart';

/// A single supplication as clean text, rather than as a picture of the page.
///
/// Arabic, transliteration and translation come from an open digital edition of
/// Hisnul Muslim whose entry numbers match the printed book's — entry 33 is the
/// dua marked ⟨33⟩ on page 31 — so every one can be checked against the scan
/// that is already bundled. [number] is that shared number.
class DuaText {
  const DuaText({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.english,
    required this.repeat,
  });

  factory DuaText.fromJson(Map<String, Object?> json) => DuaText(
        number: json['n']! as int,
        arabic: json['arabic']! as String,
        transliteration: json['translit']! as String,
        english: json['english']! as String,
        repeat: json['repeat']! as int,
      );

  final int number;
  final String arabic;
  final String transliteration;
  final String english;

  /// How many times the book says to repeat it. 0 when it does not say.
  final int repeat;
}

class DuaTextSection {
  const DuaTextSection({
    required this.section,
    required this.title,
    required this.duas,
  });

  factory DuaTextSection.fromJson(Map<String, Object?> json) => DuaTextSection(
        section: json['section']! as int,
        title: json['title']! as String,
        duas: (json['duas']! as List<Object?>)
            .map((Object? e) => DuaText.fromJson(e! as Map<String, Object?>))
            .toList(),
      );

  /// The book's section number, so the printed pages can be looked up.
  final int section;
  final String title;
  final List<DuaText> duas;
}

/// Loads the trial data. Only the prayer sections are covered so far.
Future<List<DuaTextSection>> loadPrayerText() async {
  final String raw =
      await rootBundle.loadString('assets/duas/prayer_text.json');
  return (jsonDecode(raw) as List<Object?>)
      .map((Object? e) => DuaTextSection.fromJson(e! as Map<String, Object?>))
      .toList();
}
