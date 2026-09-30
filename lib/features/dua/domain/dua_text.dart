import 'dart:convert';

import 'package:flutter/services.dart';

import '../../tasbih/domain/quran_passages.dart';

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

  /// Empty for the forty entries the source edition leaves untransliterated,
  /// and for two that carry no English. The screen omits the line rather than
  /// printing a blank one, and never invents a replacement.
  final String transliteration;
  final String english;

  /// False for section 132, the book's closing chapter of etiquette — advice
  /// rather than a supplication, so there is nothing to recite.
  bool get hasArabic => arabic.trim().isNotEmpty;

  /// Three entries quote the Qur'an but carry no transliteration in the source
  /// edition, and one carries an instruction in the transliteration field
  /// instead ("Then recite [Soorah al-Ikhlaas (112)]…"). Those passages are
  /// already transliterated elsewhere in the app, from quran.com's word-level
  /// romanisation, so they are borrowed rather than left blank or invented.
  static final Map<int, String> _quranic = <int, String>{
    70: _threeQuls,
    71: QuranPassages.ayatAlKursi.spoken,
    76: _threeQuls,
  };

  static final String _threeQuls = <String>[
    QuranPassages.ikhlas.spoken,
    QuranPassages.falaq.spoken,
    QuranPassages.nas.spoken,
  ].join('  ');

  String get spoken => _quranic[number] ?? transliteration;

  bool get hasTransliteration => spoken.trim().isNotEmpty && !_isProse;

  /// The transliteration field of n=76 holds an English sentence. Labelling
  /// that "Transliteration" is what made it look like the text had gone
  /// missing, when it had only landed in the wrong field.
  bool get _isProse =>
      _quranic[number] == null &&
      RegExp(r'^\s*(Then |Recite |Read |Say )').hasMatch(transliteration);

  /// The stray instruction, when there is one, so it can be shown as a note.
  String? get note => _isProse ? transliteration.trim() : null;
  bool get hasEnglish => english.trim().isNotEmpty;

  /// How many times the book says to repeat it. 0 when it does not say.
  final int repeat;
}

class DuaTextSection {
  const DuaTextSection({
    required this.section,
    required this.title,
    required this.duas,
  });

  factory DuaTextSection.fromChapter(int number, Map<String, Object?> json) =>
      DuaTextSection(
        section: number,
        title: json['title']! as String,
        duas: (json['duas']! as List<Object?>)
            .map((Object? e) => DuaText.fromJson(e! as Map<String, Object?>))
            .toList(),
      );

  /// The book's section number, so the printed pages can be looked up.
  final int section;
  final String title;
  final List<DuaText> duas;

  /// Where [number] sits in this section, counting from 1.
  ///
  /// This is the number people see. The book numbers its supplications
  /// straight through — the first dua of the evening adhkar is 75 — and
  /// "Dua 75" under a heading that lists six of them reads as nonsense.
  /// The book's own number stays available for looking up the printed page.
  int positionOf(int number) {
    final int i = duas.indexWhere((DuaText d) => d.number == number);
    return i < 0 ? 0 : i + 1;
  }
}

/// Every section of the book as clean text, keyed by its number.
///
/// Deliberately keyed by number rather than grouped into categories: the
/// catalogue already decides which sections sit under Sleep or Travel, and
/// duplicating that grouping in the data would give two places to disagree.
/// This file only answers "what is in section 27".
///
/// Loaded once. It is 223KB of JSON and the library reopens constantly.
Map<int, DuaTextSection>? _cache;

Future<Map<int, DuaTextSection>> loadDuaText() async {
  if (_cache != null) return _cache!;
  final String raw = await rootBundle.loadString('assets/duas/dua_text.json');
  final Map<String, Object?> map = jsonDecode(raw) as Map<String, Object?>;
  return _cache = map.map(
    (String number, Object? value) => MapEntry<int, DuaTextSection>(
      int.parse(number),
      DuaTextSection.fromChapter(
        int.parse(number),
        value! as Map<String, Object?>,
      ),
    ),
  );
}

/// The text chapter behind a section of the library.
///
/// The library's numbers are the printed book's, and its contents page opens
/// with a chapter the digital edition does not carry — so for the first
/// fifteen sections the text sits one chapter *earlier* than the number says,
/// and from §16 (the beginning of prayer) the two agree again. Looking the
/// text up by the book's number directly is what put the dua for *leaving the
/// house* under "Completing Ablution": every Daily Life row was showing the
/// next section's words.
int chapterForSection(int bookSection) =>
    bookSection <= 15 ? bookSection - 1 : bookSection;

/// The text of one section, or null where the book has none under that number.
Future<DuaTextSection?> loadSectionText(int number) async =>
    (await loadDuaText())[number];
