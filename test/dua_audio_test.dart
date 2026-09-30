import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/dua/application/dua_audio_handler.dart';
import 'package:noor/features/dua/domain/dua_catalogue.dart';
import 'package:noor/features/dua/domain/dua_text.dart';

/// The recitations and the queue they play in.
///
/// Two things went wrong before this existed. The library looked the text up
/// by the book's section number, and for the first fifteen sections that is
/// one chapter off — "Completing Ablution" opened on the dua for leaving the
/// house, which is why the dua after wudu could not be found. And there was
/// no audio at all.
void main() {
  group('Section numbers reach the right text', () {
    test('the first fifteen sections sit one chapter earlier', () {
      expect(chapterForSection(2), 1); // Waking up
      expect(chapterForSection(9), 8); // Before ablution
      expect(chapterForSection(10), 9); // Completing ablution
      expect(chapterForSection(15), 14); // Leaving the mosque
    });

    test('from the beginning of prayer onwards they agree', () {
      expect(chapterForSection(16), 16);
      expect(chapterForSection(27), 27);
      expect(chapterForSection(108), 108);
    });

    test('every section in the library has a chapter', () {
      for (final DuaCategory c in duaCategories) {
        for (final DuaSection s in c.sections) {
          expect(chapterForSection(s.number), greaterThan(0), reason: s.title);
        }
      }
    });
  });

  group('The queue', () {
    const List<DuaText> duas = <DuaText>[
      DuaText(
        number: 13,
        arabic: 'أَشْهَدُ',
        transliteration: '',
        english: '',
        repeat: 1,
      ),
      DuaText(
        number: 14,
        arabic: 'اللَّهُمَّ',
        transliteration: '',
        english: '',
        repeat: 1,
      ),
      // Section 132 is etiquette, not a supplication: nothing to recite.
      DuaText(
        number: 267,
        arabic: '',
        transliteration: '',
        english: 'x',
        repeat: 0,
      ),
    ];

    test('reads each dua the chosen number of times, then moves on', () {
      final List<DuaQueueItem> q = buildDuaQueue(duas, repeat: 3);
      expect(
        q.map((DuaQueueItem i) => '${i.number}/${i.pass}').toList(),
        <String>['13/1', '13/2', '13/3', '14/1', '14/2', '14/3'],
      );
      expect(q.every((DuaQueueItem i) => i.passes == 3), isTrue);
    });

    test('once is once, and the count is held to one to ten', () {
      expect(buildDuaQueue(duas, repeat: 1).length, 2);
      expect(buildDuaQueue(duas, repeat: 0).length, 2);
      expect(buildDuaQueue(duas, repeat: 99).length, 20);
    });

    test('a dua with no Arabic has no recording and is skipped', () {
      expect(
        buildDuaQueue(duas, repeat: 1).any((DuaQueueItem i) => i.number == 267),
        isFalse,
      );
    });
  });

  test('every dua with Arabic has a bundled recording', () async {
    final Map<int, DuaTextSection> text = _loadText();
    final List<int> missing = <int>[];
    for (final DuaTextSection section in text.values) {
      for (final DuaText dua in section.duas) {
        if (!dua.hasArabic) continue;
        if (!File(DuaAudioHandler.assetFor(dua.number)).existsSync()) {
          missing.add(dua.number);
        }
      }
    }
    expect(missing, isEmpty, reason: 'no recording for $missing');
  });
}

Map<int, DuaTextSection> _loadText() {
  // Read straight from disk: the asset bundle is not available in a unit
  // test, and the point is to check the files that will be bundled. The file
  // starts with a byte-order mark that `jsonDecode` refuses.
  final String raw = File('assets/duas/dua_text.json').readAsStringSync();
  final String clean = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
  final Map<String, Object?> map = jsonDecode(clean) as Map<String, Object?>;
  return map.map(
    (String number, Object? value) => MapEntry<int, DuaTextSection>(
      int.parse(number),
      DuaTextSection.fromChapter(
        int.parse(number),
        value! as Map<String, Object?>,
      ),
    ),
  );
}
