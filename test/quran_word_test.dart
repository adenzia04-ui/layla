import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/quran/domain/ayah_words.dart';
import 'package:noor/features/quran/domain/mushaf_glyphs.dart';
import 'package:noor/features/quran/domain/quran_data.dart';
import 'package:noor/features/quran/domain/reciters.dart';
import 'package:noor/features/quran/domain/surah_search.dart';
import 'package:noor/features/quran/domain/word_timing.dart';

void main() {
  late Quran quran;
  late MushafGlyphs glyphs;

  setUpAll(() {
    quran = parseQuran(File('assets/quran/quran.json').readAsStringSync());
    glyphs = MushafGlyphs.parse(
      File('assets/quran/glyphs.json').readAsStringSync(),
    );
  });

  group('Word boxes on the page', () {
    test('every page has boxes, measured on the bundled image size', () {
      expect(glyphs.pageCount, Quran.pageCount);
      expect(glyphs.imageSize, const Size(1260, 2038));
      for (int p = 1; p <= Quran.pageCount; p++) {
        expect(glyphs.page(p)!.glyphs, isNotEmpty, reason: 'page $p');
      }
    });

    test('the boxes count the text\'s tokens, plus the ayah-end mark', () {
      int off = 0;
      for (final Surah s in quran.surahs) {
        for (final Ayah a in quran.ayahsOf(s.number)) {
          final List<Glyph> g = glyphs.page(a.page)!.ofAyah(a.key);
          final int tokens = ayahTokens(a.arabic).length;
          if (g.length != tokens + 1) off++;
        }
      }
      // 13:37 is set with one glyph fewer in the source data; nothing
      // else may drift, or a lit word would land on its neighbour.
      expect(off, lessThanOrEqualTo(1));
    });

    test('a touch between two words still lands on one', () {
      final PageGlyphs p = glyphs.page(604)!;
      final Glyph first = p.ofAyah('112:1').first;
      final Glyph? hit = p.hit(first.box.centerLeft - const Offset(4, 0));
      expect(hit, isNotNull);
      expect(hit!.ayahKey, '112:1');
      expect(p.hit(const Offset(-50, -50)), isNull);
    });
  });

  group('Word timings', () {
    test('every timed voice is a reciter we offer, and vice versa', () {
      for (final String v in timedVoices) {
        expect(reciters.any((Reciter r) => r.id == v), isTrue, reason: v);
        expect(File('assets/quran/timing/$v.json').existsSync(), isTrue);
      }
    });

    test('a voice covers every ayah and never more words than the text', () {
      for (final String v in timedVoices) {
        final VoiceTiming t = VoiceTiming.parse(
          v,
          File('assets/quran/timing/$v.json').readAsStringSync(),
        );
        expect(t.ayahCount, 6236, reason: v);
        int over = 0;
        int empty = 0;
        for (final Surah s in quran.surahs) {
          for (final Ayah a in quran.ayahsOf(s.number)) {
            final List<WordSpan> spans = t.of(a.key);
            if (spans.isEmpty) empty++;
            final int words = ayahTokens(
              a.arabic,
            ).where((String w) => !isMarkToken(w)).length;
            if (spans.isNotEmpty && spans.last.position > words) over++;
          }
        }
        expect(over, 0, reason: '$v points past the last word');
        expect(empty, lessThan(20), reason: '$v has $empty untimed ayahs');
      }
    });

    test('the word at a moment is the one whose span holds it', () {
      final VoiceTiming t = VoiceTiming.parse(
        'alafasy',
        File('assets/quran/timing/alafasy.json').readAsStringSync(),
      );
      // 1:1 in Alafasy: [[60,610],[620,1310],[1320,2450],[2460,5970]]
      expect(t.wordAt('1:1', 0), 0);
      expect(t.wordAt('1:1', 100), 1);
      expect(t.wordAt('1:1', 615), 1, reason: 'a breath keeps the word');
      expect(t.wordAt('1:1', 700), 2);
      expect(t.wordAt('1:1', 5000), 4);
      expect(t.wordAt('1:1', 9000), 0);
    });
  });

  group('Tokens, words and marks', () {
    test('a lone pause mark is a token but not a word', () {
      final Ayah a = quran.ayahsOf(2)[1]; // 2:2 has two ۛ marks
      final List<String> tokens = ayahTokens(a.arabic);
      expect(tokens.length, 9);
      expect(tokens.where(isMarkToken).length, 2);
      expect(wordToken(tokens, 4), 3); // رَيْبَ
      expect(wordToken(tokens, 5), 5); // فِيهِ, past the first mark
      expect(wordToken(tokens, 8), -1);
      expect(tokenWord(tokens, 4), 0); // the mark itself
      expect(tokenWord(tokens, 5), 5);
    });
  });

  group('Finding a surah', () {
    test('a letter matches names that start with it, article skipped', () {
      final List<String> d = quran.surahs
          .where((Surah s) => surahMatch(s, 'd') > 0)
          .map((Surah s) => s.name)
          .toList();
      expect(d, containsAll(<String>['Ad-Duhaa', 'Ad-Dukhan']));
      expect(d, isNot(contains('Ar-Ra\'d')));
      expect(d, isNot(contains('Al-Fajr')));
      final List<String> a = quran.surahs
          .where((Surah s) => surahMatch(s, 'a') > 0)
          .map((Surah s) => s.name)
          .toList();
      expect(a.length, greaterThan(60));
    });

    test('a number, the bare name, and a meaning all work', () {
      expect(surahMatch(quran.surah(112), '112'), 4);
      expect(surahMatch(quran.surah(1), 'fat'), 3);
      expect(surahMatch(quran.surah(1), 'alf'), 3);
      expect(surahMatch(quran.surah(2), 'cow'), 1);
      expect(surahMatch(quran.surah(2), 'c'), 0);
      expect(surahMatch(quran.surah(36), 'ya'), 3);
    });
  });
}
