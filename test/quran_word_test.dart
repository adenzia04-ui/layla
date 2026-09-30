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

    test('every voice has one entry per word, in order, moving forward', () {
      for (final String v in timedVoices) {
        final VoiceTiming t = VoiceTiming.parse(
          v,
          File('assets/quran/timing/$v.json').readAsStringSync(),
        );
        expect(t.ayahCount, 6236, reason: v);
        int untimed = 0;
        for (final Surah s in quran.surahs) {
          for (final Ayah a in quran.ayahsOf(s.number)) {
            final List<WordSpan> spans = t.of(a.key);
            if (spans.isEmpty) {
              untimed++;
              continue;
            }
            final int words = ayahTokens(
              a.arabic,
            ).where((String w) => !isMarkToken(w)).length;
            expect(spans.length, words, reason: '$v ${a.key} word count');
            for (int i = 0; i < spans.length; i++) {
              expect(spans[i].position, i + 1, reason: '$v ${a.key}');
              expect(
                spans[i].end,
                greaterThan(spans[i].start),
                reason: '$v ${a.key} word ${i + 1}',
              );
              if (i > 0) {
                expect(
                  spans[i].start,
                  greaterThan(spans[i - 1].start),
                  reason: '$v ${a.key} word ${i + 1} runs backwards',
                );
              }
            }
          }
        }
        // Shatri 37:66 and 37:67 recite the ayah several times over; they
        // are left to the ayah-level light on purpose.
        expect(untimed, v == 'shatri' ? 2 : 0, reason: '$v: $untimed untimed');
      }
    });

    test('Sudais moves word by word through a long ayah', () {
      // His timings arrive as strings; sorted as strings, "10" came before
      // "2" and every ayah over nine words was scrambled.
      final VoiceTiming t = VoiceTiming.parse(
        'sudais',
        File('assets/quran/timing/sudais.json').readAsStringSync(),
      );
      int last = 0;
      for (int ms = 0; ms < 38000; ms += 40) {
        final int w = t.wordAt('2:255', ms);
        if (w == 0) continue;
        expect(w, greaterThanOrEqualTo(last), reason: 'at $ms ms');
        expect(w - last, lessThanOrEqualTo(1), reason: 'skipped at $ms ms');
        last = w;
      }
      expect(last, 50);
      expect(t.wordAt('2:255', 1000), 2);
      expect(t.wordAt('2:255', 7000), 10);
    });

    test('quran.com\'s word numbers land on our words', () {
      VoiceTiming load(String v) => VoiceTiming.parse(
        v,
        File('assets/quran/timing/$v.json').readAsStringSync(),
      );
      // "بَعْدَ مَا" is one word to quran.com and two to us. Without the
      // alignment every later word lit one early and the last one got a
      // made-up flash after the recitation ended.
      for (final String v in timedVoices) {
        final List<WordSpan> s = load(v).of('8:6');
        expect(s.length, 12, reason: v);
        expect(s[3].end, lessThanOrEqualTo(s[4].start), reason: v);
      }
      expect(load('sudais').of('8:6').last.start, 7940);
      // A phantom word number after the opening letters (13:1, Alafasy)
      // pushed everything one word late; the real last word is kept.
      expect(load('alafasy').of('13:1').last.start, 27940);
      // A last segment that runs to the end of the recording is the rest
      // of the ayah, shared out — not one word lasting a minute.
      final List<WordSpan> ab = load('abdulbasit').of('6:70');
      expect(ab.length, 45);
      expect(ab[13].end - ab[13].start, lessThan(8000));
      expect(ab.last.end, lessThanOrEqualTo(79860));
    });

    test('37:130: segments that count our words are taken as ours', () {
      // quran.com's word list joins "إِلْ يَاسِينَ"; its timings do not.
      // Clamped to the joined list, the last word's segment was dropped
      // and the end of the ayah never lit.
      final VoiceTiming t = VoiceTiming.parse(
        'alafasy',
        File('assets/quran/timing/alafasy.json').readAsStringSync(),
      );
      final List<WordSpan> s = t.of('37:130');
      expect(s.length, 4);
      expect(s[3].start, 3430);
      expect(s[3].end, 6290);
    });

    test('an untimed repeat lets the light go out', () {
      // Rifai 8:36: the data holds word 8 from 8.2 s to 29 s while he
      // repeats an earlier phrase. The light goes out rather than sit on
      // the wrong word, and returns with word 9.
      final VoiceTiming t = VoiceTiming.parse(
        'rifai',
        File('assets/quran/timing/rifai.json').readAsStringSync(),
      );
      final List<WordSpan> s = t.of('8:36');
      expect(s[7].end - s[7].start, lessThan(4000));
      expect(t.wordAt('8:36', s[7].start + 100), 8);
      expect(t.wordAt('8:36', s[7].end + 3000), 0);
      expect(t.wordAt('8:36', s[8].start + 10), 9);
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
      expect(t.wordAt('1:1', 7000), 4, reason: 'a held last word stays lit');
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
