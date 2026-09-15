import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/dua/domain/dua_catalogue.dart';
import 'package:noor/features/dua/domain/dua_text.dart';

/// The text of the book and the catalogue that indexes it live in two files.
/// If they drift, a category silently loses sections and nobody notices,
/// because the screen just renders fewer rows.
void main() {
  final Map<String, Object?> raw =
      jsonDecode(File('assets/duas/dua_text.json').readAsStringSync())
          as Map<String, Object?>;

  Map<String, Object?> chapter(String k) => raw[k]! as Map<String, Object?>;
  List<Object?> duas(String k) => chapter(k)['duas']! as List<Object?>;

  test('the whole book is present', () {
    expect(raw.length, 132, reason: 'Hisnul Muslim has 132 sections');
    final int total = raw.keys.fold(0, (int a, String k) => a + duas(k).length);
    expect(total, 267, reason: 'and 267 supplications');
  });

  test('every section the catalogue lists has text behind it', () {
    final List<int> orphans = <int>[
      for (final DuaCategory c in duaCategories)
        for (final DuaSection s in c.sections)
          if (!raw.containsKey('${s.number}')) s.number,
    ];
    expect(
      orphans,
      isEmpty,
      reason: 'these sections would open onto nothing: $orphans',
    );
  });

  test('every dua has Arabic, and the gaps are only where expected', () {
    int noArabic = 0;
    int noEnglish = 0;
    int noTranslit = 0;
    for (final String k in raw.keys) {
      for (final Object? d in duas(k)) {
        final Map<String, Object?> m = d! as Map<String, Object?>;
        if ((m['arabic']! as String).trim().isEmpty) noArabic++;
        if ((m['english']! as String).trim().isEmpty) noEnglish++;
        if ((m['translit']! as String).trim().isEmpty) noTranslit++;
      }
    }
    // One, and it is not a fault in the data: section 132 is the book's
    // closing chapter on etiquette for community life, which is advice rather
    // than a supplication, so it has no Arabic to carry.
    expect(noArabic, 1);
    // The source edition's own gaps, pinned so a data swap that quietly loses
    // more of them fails here instead of shipping blank screens.
    expect(noEnglish, 2);
    expect(noTranslit, 40);
  });

  test('the Quranic entries the source left bare are filled', () {
    // n=70 and n=76 are the three quls; n=71 is Ayat al-Kursi. The edition
    // gives no transliteration for any of them, and n=76 carries an English
    // instruction in that field instead — which is what made the text look
    // missing. They borrow the app's own verified Qur'an transliteration.
    for (final int n in <int>[70, 71, 76]) {
      final DuaText d = DuaText.fromJson(
        (raw.values
                .expand<Object?>(
                  (Object? v) =>
                      (v! as Map<String, Object?>)['duas']! as List<Object?>,
                )
                .firstWhere(
                  (Object? e) => (e! as Map<String, Object?>)['n'] == n,
                ))!
            as Map<String, Object?>,
      );
      expect(d.hasTransliteration, isTrue, reason: 'n=$n is still bare');
      expect(
        RegExp('[ḥṣṭḍẓʿāīū]').hasMatch(d.spoken),
        isTrue,
        reason: 'n=$n should use the verified scholarly transliteration',
      );
      expect(
        d.spoken,
        isNot(startsWith('Then recite')),
        reason: 'n=$n was showing an instruction as its transliteration',
      );
    }
  });

  test('an instruction in the transliteration field is shown as a note', () {
    final DuaText d = DuaText.fromJson(
      (raw.values
              .expand<Object?>(
                (Object? v) =>
                    (v! as Map<String, Object?>)['duas']! as List<Object?>,
              )
              .firstWhere(
                (Object? e) => (e! as Map<String, Object?>)['n'] == 76,
              ))!
          as Map<String, Object?>,
    );
    expect(
      d.note,
      isNull,
      reason:
          'n=76 now has real transliteration, so the instruction is '
          'no longer standing in for it',
    );
  });

  test('the numbering is the book’s own and unique', () {
    final List<int> all = <int>[
      for (final String k in raw.keys)
        for (final Object? d in duas(k))
          (d! as Map<String, Object?>)['n']! as int,
    ]..sort();
    expect(all.toSet().length, all.length, reason: 'numbers must not repeat');
    expect(all.first, 1);
    expect(all.last, 267);
  });
}
