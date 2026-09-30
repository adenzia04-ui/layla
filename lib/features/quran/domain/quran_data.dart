import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One surah's entry in the table of contents.
@immutable
class Surah {
  const Surah({
    required this.number,
    required this.name,
    required this.arabicName,
    required this.meaning,
    required this.place,
    required this.ayahCount,
    required this.firstPage,
    required this.lastPage,
    required this.hasBismillah,
  });

  factory Surah.fromJson(Map<String, Object?> j) => Surah(
    number: j['n']! as int,
    name: j['name']! as String,
    arabicName: j['arabic']! as String,
    meaning: j['meaning']! as String,
    place: j['place']! as String,
    ayahCount: j['count']! as int,
    firstPage: (j['pages']! as List<Object?>).first! as int,
    lastPage: (j['pages']! as List<Object?>).last! as int,
    hasBismillah: j['bismillah']! as bool,
  );

  final int number;
  final String name;
  final String arabicName;
  final String meaning;

  /// `makkah` or `madinah`.
  final String place;
  final int ayahCount;
  final int firstPage;
  final int lastPage;

  /// False for At-Tawbah, the one surah that opens without the basmalah.
  /// Al-Fatihah's basmalah is its first ayah, so it is not printed twice.
  final bool hasBismillah;

  bool get isMakki => place == 'makkah';
}

/// One ayah, with everything the reader shows for it.
@immutable
class Ayah {
  const Ayah({
    required this.surah,
    required this.number,
    required this.arabic,
    required this.translation,
    required this.transliteration,
    required this.page,
    required this.juz,
  });

  factory Ayah.fromJson(int surah, Map<String, Object?> j) => Ayah(
    surah: surah,
    number: j['a']! as int,
    arabic: j['ar']! as String,
    translation: j['en']! as String,
    transliteration: j['tl']! as String,
    page: j['p']! as int,
    juz: j['j']! as int,
  );

  final int surah;
  final int number;

  /// Uthmani script, as the Madinah mushaf writes it.
  final String arabic;

  /// Saheeh International.
  final String translation;
  final String transliteration;
  final int page;
  final int juz;

  /// `2:255` — how the ayah is named everywhere outside the app too.
  String get key => '$surah:$number';
}

/// The whole book, parsed once.
class Quran {
  const Quran({required this.surahs, required Map<int, List<Ayah>> ayahs})
    : _ayahs = ayahs;

  final List<Surah> surahs;
  final Map<int, List<Ayah>> _ayahs;

  Surah surah(int number) => surahs[number - 1];

  List<Ayah> ayahsOf(int surah) => _ayahs[surah] ?? const <Ayah>[];

  Ayah ayah(int surah, int number) => ayahsOf(surah)[number - 1];

  /// Every ayah printed on [page], in reading order. Pages run 1–604.
  List<Ayah> onPage(int page) => <Ayah>[
    for (final Surah s in surahs)
      if (s.firstPage <= page && page <= s.lastPage)
        for (final Ayah a in ayahsOf(s.number))
          if (a.page == page) a,
  ];

  /// The surahs that begin on [page], for the page header.
  List<Surah> surahsOnPage(int page) => <Surah>[
    for (final Surah s in surahs)
      if (s.firstPage <= page && page <= s.lastPage) s,
  ];

  /// The juz a page belongs to, read off its first ayah.
  int juzOfPage(int page) {
    final List<Ayah> on = onPage(page);
    return on.isEmpty ? 1 : on.first.juz;
  }

  static const int pageCount = 604;

  int get ayahCount =>
      _ayahs.values.fold<int>(0, (int n, List<Ayah> l) => n + l.length);
}

/// Parsed off the main thread: it is three megabytes of JSON, and the first
/// open of the Qur'an should not stall the tap that opened it.
Quran parseQuran(String raw) {
  final Map<String, Object?> map = jsonDecode(raw) as Map<String, Object?>;
  final List<Surah> surahs = (map['chapters']! as List<Object?>)
      .map((Object? e) => Surah.fromJson(e! as Map<String, Object?>))
      .toList();
  final Map<String, Object?> verses = map['verses']! as Map<String, Object?>;
  final Map<int, List<Ayah>> ayahs = <int, List<Ayah>>{
    for (final MapEntry<String, Object?> e in verses.entries)
      int.parse(e.key): (e.value! as List<Object?>)
          .map(
            (Object? v) =>
                Ayah.fromJson(int.parse(e.key), v! as Map<String, Object?>),
          )
          .toList(),
  };
  return Quran(surahs: surahs, ayahs: ayahs);
}

Future<Quran>? _loading;

/// The bundled book. Loaded once and kept: every screen in the Qur'an
/// section opens onto it.
Future<Quran> loadQuran() => _loading ??= rootBundle
    .loadString('assets/quran/quran.json')
    .then((String raw) => compute(parseQuran, raw));
