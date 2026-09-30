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
    required this.revelationOrder,
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
    revelationOrder: (j['order'] as int?) ?? 0,
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

  /// False for At-Tawbah, the one surah that opens without the basmalah,
  /// and for Al-Fatihah, whose basmalah is its own first ayah.
  final bool hasBismillah;

  /// Where this surah came in the order of revelation, 1–114.
  final int revelationOrder;

  bool get isMakki => place == 'makkah';
  int get pageCount => lastPage - firstPage + 1;
}

/// One ayah, with everything the reader shows for it.
@immutable
class Ayah {
  const Ayah({
    required this.surah,
    required this.number,
    required this.arabic,
    required this.translations,
    required this.transliteration,
    required this.page,
    required this.juz,
  });

  factory Ayah.fromJson(int surah, Map<String, Object?> j) {
    final Map<String, String> tr = <String, String>{
      // Saheeh International keeps its old field; the rest arrived later.
      '20': j['en']! as String,
      for (final MapEntry<String, Object?> e
          in ((j['tr'] as Map<String, Object?>?) ?? const <String, Object?>{})
              .entries)
        e.key: e.value! as String,
    };
    return Ayah(
      surah: surah,
      number: j['a']! as int,
      arabic: j['ar']! as String,
      translations: tr,
      transliteration: j['tl']! as String,
      page: j['p']! as int,
      juz: j['j']! as int,
    );
  }

  final int surah;
  final int number;

  /// Uthmani script, as the Madinah mushaf writes it.
  final String arabic;

  /// Keyed by translation id — see `translations.dart`.
  final Map<String, String> translations;
  final String transliteration;
  final int page;
  final int juz;

  /// Saheeh International, the default.
  String get translation => translations['20'] ?? '';

  /// `2:255` — how the ayah is named everywhere outside the app too.
  String get key => '$surah:$number';
}

/// One of the thirty juz: where it begins.
@immutable
class Juz {
  const Juz({
    required this.number,
    required this.firstAyah,
    required this.firstPage,
  });

  final int number;
  final Ayah firstAyah;
  final int firstPage;

  /// The traditional Arabic name, "الجزء الأول".
  String get arabicName => 'الجزء ${juzOrdinals[number - 1]}';
}

/// The Arabic ordinals the mushaf prints in its page headers.
const List<String> juzOrdinals = <String>[
  'الأول',
  'الثاني',
  'الثالث',
  'الرابع',
  'الخامس',
  'السادس',
  'السابع',
  'الثامن',
  'التاسع',
  'العاشر',
  'الحادي عشر',
  'الثاني عشر',
  'الثالث عشر',
  'الرابع عشر',
  'الخامس عشر',
  'السادس عشر',
  'السابع عشر',
  'الثامن عشر',
  'التاسع عشر',
  'العشرون',
  'الحادي والعشرون',
  'الثاني والعشرون',
  'الثالث والعشرون',
  'الرابع والعشرون',
  'الخامس والعشرون',
  'السادس والعشرون',
  'السابع والعشرون',
  'الثامن والعشرون',
  'التاسع والعشرون',
  'الثلاثون',
];

/// The whole book, parsed once.
class Quran {
  Quran({required this.surahs, required Map<int, List<Ayah>> ayahs})
    : _ayahs = ayahs {
    // Page → ayahs, built once: the mushaf asks for it on every page turn.
    for (final Surah s in surahs) {
      for (final Ayah a in ayahsOf(s.number)) {
        (_byPage[a.page] ??= <Ayah>[]).add(a);
        if (!_juzStart.containsKey(a.juz)) _juzStart[a.juz] = a;
      }
    }
  }

  final List<Surah> surahs;
  final Map<int, List<Ayah>> _ayahs;
  final Map<int, List<Ayah>> _byPage = <int, List<Ayah>>{};
  final Map<int, Ayah> _juzStart = <int, Ayah>{};

  Surah surah(int number) => surahs[number - 1];

  List<Ayah> ayahsOf(int surah) => _ayahs[surah] ?? const <Ayah>[];

  Ayah ayah(int surah, int number) => ayahsOf(surah)[number - 1];

  /// Every ayah printed on [page], in reading order. Pages run 1–604.
  List<Ayah> onPage(int page) => _byPage[page] ?? const <Ayah>[];

  /// The surahs with any ayah on [page], for the page header.
  List<Surah> surahsOnPage(int page) => <Surah>[
    for (final Surah s in surahs)
      if (s.firstPage <= page && page <= s.lastPage) s,
  ];

  /// The juz a page belongs to, read off its first ayah.
  int juzOfPage(int page) {
    final List<Ayah> on = onPage(page);
    return on.isEmpty ? 1 : on.first.juz;
  }

  /// The thirty juz, in order.
  List<Juz> get juzs => <Juz>[
    for (int n = 1; n <= 30; n++)
      if (_juzStart[n] case final Ayah a)
        Juz(number: n, firstAyah: a, firstPage: a.page),
  ];

  /// The surahs in the order they were revealed.
  List<Surah> get byRevelation =>
      <Surah>[...surahs]
        ..sort((Surah a, Surah b) => a.revelationOrder - b.revelationOrder);

  static const int pageCount = 604;

  int get ayahCount =>
      _ayahs.values.fold<int>(0, (int n, List<Ayah> l) => n + l.length);
}

/// Parsed off the main thread: it is eight megabytes of JSON, and the first
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
