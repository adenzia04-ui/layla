import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/audio/recitation_handler.dart';
import 'package:noor/features/quran/application/tafsir_service.dart';
import 'package:noor/features/quran/domain/quran_data.dart';
import 'package:noor/features/quran/domain/quran_queue.dart';
import 'package:noor/features/quran/domain/reciters.dart';
import 'package:noor/features/quran/domain/translations.dart';

/// The bundled Qur'an, checked as a whole: 114 surahs, 6,236 ayahs, 604
/// pages with none missing, and a page image for every page. A book with a
/// page missing is not the book.
void main() {
  late Quran quran;

  setUpAll(() {
    quran = parseQuran(File('assets/quran/quran.json').readAsStringSync());
  });

  group('The bundled book', () {
    test('has every surah and every ayah', () {
      expect(quran.surahs.length, 114);
      expect(quran.ayahCount, 6236);
      for (final Surah s in quran.surahs) {
        expect(quran.ayahsOf(s.number).length, s.ayahCount, reason: s.name);
        expect(quran.surah(s.number).number, s.number);
      }
      expect(quran.surah(1).name, 'Al-Fatihah');
      expect(quran.surah(114).name, 'An-Nas');
    });

    test('ayahs are numbered in order with no gaps', () {
      for (final Surah s in quran.surahs) {
        final List<Ayah> ayahs = quran.ayahsOf(s.number);
        for (int i = 0; i < ayahs.length; i++) {
          expect(ayahs[i].number, i + 1, reason: '${s.number}:${i + 1}');
          expect(ayahs[i].surah, s.number);
        }
      }
    });

    test('every ayah has Arabic, a translation and a transliteration', () {
      for (final Surah s in quran.surahs) {
        for (final Ayah a in quran.ayahsOf(s.number)) {
          expect(a.arabic.trim(), isNotEmpty, reason: a.key);
          expect(a.translation.trim(), isNotEmpty, reason: a.key);
          expect(a.transliteration.trim(), isNotEmpty, reason: a.key);
          // No markup leaks into the text people read.
          expect(a.translation, isNot(contains('<')), reason: a.key);
          expect(a.transliteration, isNot(contains('<')), reason: a.key);
        }
      }
    });

    test('covers all 604 pages, in order, with a bundled image for each', () {
      final Set<int> pages = <int>{};
      int last = 0;
      for (final Surah s in quran.surahs) {
        for (final Ayah a in quran.ayahsOf(s.number)) {
          expect(a.page, greaterThanOrEqualTo(last), reason: a.key);
          last = a.page;
          pages.add(a.page);
        }
      }
      expect(pages.length, Quran.pageCount);
      expect(pages.reduce((int a, int b) => a < b ? a : b), 1);
      expect(pages.reduce((int a, int b) => a > b ? a : b), Quran.pageCount);
      final List<int> missing = <int>[
        for (int p = 1; p <= Quran.pageCount; p++)
          if (!File('assets/quran/pages/$p.png').existsSync()) p,
      ];
      expect(missing, isEmpty, reason: 'no image for pages $missing');
    });

    test('knows what is on a page', () {
      expect(quran.onPage(1).map((Ayah a) => a.key), <String>[
        for (int i = 1; i <= 7; i++) '1:$i',
      ]);
      expect(quran.surahsOnPage(1).single.number, 1);
      // Page 2 opens Al-Baqarah; page 604 closes the book.
      expect(quran.onPage(2).first.key, '2:1');
      expect(quran.onPage(604).last.key, '114:6');
      expect(quran.juzOfPage(604), 30);
      expect(quran.surah(2).firstPage, 2);
      expect(quran.surah(2).lastPage, 49);
    });

    test('knows where the basmalah is printed', () {
      // Al-Fatihah's basmalah is its own first ayah, so nothing is printed
      // before it — the source marks it false, and the reader relies on that.
      expect(quran.surah(1).hasBismillah, isFalse);
      expect(quran.ayah(1, 1).arabic, startsWith('بِسْمِ'));
      expect(quran.surah(9).hasBismillah, isFalse);
      expect(quran.surah(2).hasBismillah, isTrue);
    });

    test('the JSON on disk is what the loader parses', () {
      final Map<String, Object?> raw =
          jsonDecode(File('assets/quran/quran.json').readAsStringSync())
              as Map<String, Object?>;
      expect((raw['chapters']! as List<Object?>).length, 114);
    });
  });

  group('The recitation queue', () {
    test('a whole surah is each ayah once, in order', () {
      final List<RecitationTrack> q = surahTracks(
        quran,
        112,
        reciter: reciters.first,
        mode: PlayMode.surah,
        repeat: 5,
      );
      expect(q.map((RecitationTrack t) => t.group), <String>[
        '112:bismillah',
        '112:1',
        '112:2',
        '112:3',
        '112:4',
      ]);
      expect(q.every((RecitationTrack t) => t.passes == 1), isTrue);
    });

    test('a surah opens with its Bismillah, where the mushaf prints one', () {
      final Reciter alafasy = reciterById('alafasy');
      List<RecitationTrack> of(int surah, Reciter r) => surahTracks(
        quran,
        surah,
        reciter: r,
        mode: PlayMode.surah,
        repeat: 1,
      );
      final RecitationTrack b = of(2, alafasy).first;
      expect(isBismillah(b), isTrue);
      // The voice's own Bismillah: its Al-Fatihah 1:1.
      expect(b.url.toString(), endsWith('Alafasy_128kbps/001001.mp3'));
      expect(b.title, 'Al-Baqarah · Bismillah');
      // Al-Fatihah's first ayah is the Bismillah; At-Tawbah has none; a
      // whole-surah file already opens with it.
      expect(of(1, alafasy).any(isBismillah), isFalse);
      expect(of(9, alafasy).any(isBismillah), isFalse);
      expect(of(2, reciterById('luhaidan')).any(isBismillah), isFalse);
      // Starting from the top plays it; starting further in does not.
      expect(trackIndexOf(of(2, alafasy), 1), 0);
      expect(trackIndexOf(of(2, alafasy), 2), 2);
    });

    test('ayah by ayah reads each one the chosen number of times', () {
      final List<RecitationTrack> q = surahTracks(
        quran,
        112,
        reciter: reciters.first,
        mode: PlayMode.ayahByAyah,
        repeat: 3,
      );
      // Still one track per ayah — the repeats are counted by the player,
      // so a long surah at 10× is not thousands of queued items.
      expect(q.length, 5);
      // The Bismillah is read once; each ayah the chosen number of times.
      expect(q.first.passes, 1);
      expect(q.skip(1).every((RecitationTrack t) => t.passes == 3), isTrue);
      expect(trackIndexOf(q, 1), 0);
      expect(trackIndexOf(q, 2), 2);
      expect(trackIndexOf(q, 4), 4);
      expect(trackIndexOf(q, 5), -1);
    });

    test('the count is held to one to ten', () {
      expect(
        surahTracks(
          quran,
          112,
          reciter: reciters.first,
          mode: PlayMode.ayahByAyah,
          repeat: 99,
        )[1].passes,
        10,
      );
    });

    test('a recording already on the device plays from the file', () {
      final List<RecitationTrack> q = surahTracks(
        quran,
        112,
        reciter: reciters.first,
        mode: PlayMode.surah,
        repeat: 1,
        localFile: (Uri u) =>
            u.path.endsWith('112002.mp3') ? '/tmp/x.mp3' : null,
      );
      expect(q[1].file, isNull);
      expect(q[2].file, '/tmp/x.mp3');
      expect(q[2].url, isNotNull);
    });

    test('every track points at the reciter’s file for that ayah', () {
      for (final Reciter r in reciters) {
        expect(
          r.url(2, 255).toString(),
          'https://everyayah.com/data/${r.folder}/002255.mp3',
        );
      }
      final RecitationTrack t = surahTracks(
        quran,
        2,
        reciter: reciterById('husary'),
        mode: PlayMode.surah,
        repeat: 1,
      )[255];
      expect(t.group, '2:255');
      expect(t.url.toString(), contains('Husary_128kbps/002255.mp3'));
      expect(t.title, 'Al-Baqarah · Ayah 255');
    });

    test('every voice is distinct and an unknown id falls back', () {
      expect(reciters.length, greaterThanOrEqualTo(12));
      expect(reciters.map((Reciter r) => r.id).toSet().length, reciters.length);
      expect(reciterById('nobody').id, reciters.first.id);
      expect(reciterById('luhaidan').perAyah, isFalse);
      expect(
        reciterById('luhaidan').surahUrl(2).toString(),
        endsWith('/002.mp3'),
      );
    });

    test('a whole-surah voice gives one track and no ayah to point at', () {
      final List<RecitationTrack> q = surahTracks(
        quran,
        2,
        reciter: reciterById('luhaidan'),
        mode: PlayMode.ayahByAyah,
        repeat: 5,
      );
      expect(q.length, 1);
      expect(q.single.group, wholeSurahGroup(2));
      expect(q.single.passes, 1);
      expect(trackIndexOf(q, 255), 0);
      expect(
        reciterById('luhaidan').filesFor(2, quran.surah(2).ayahCount).length,
        1,
      );
      expect(
        reciterById('alafasy').filesFor(2, quran.surah(2).ayahCount).length,
        286,
      );
    });
  });

  group('Translations and the order of the book', () {
    test('five translations, all present on every ayah', () {
      expect(translations.length, 5);
      for (final Surah s in quran.surahs) {
        for (final Ayah a in quran.ayahsOf(s.number)) {
          for (final Translation t in translations) {
            expect(
              a.translations[t.id]?.trim(),
              isNotEmpty,
              reason: '${a.key} ${t.id}',
            );
            expect(a.translations[t.id], isNot(contains('<')), reason: a.key);
          }
        }
      }
      expect(quran.ayah(1, 1).translations['20'], quran.ayah(1, 1).translation);
    });

    test('every surah has a revelation order, each used once', () {
      final Set<int> orders = quran.surahs
          .map((Surah s) => s.revelationOrder)
          .toSet();
      expect(orders.length, 114);
      expect(orders.reduce((int a, int b) => a < b ? a : b), 1);
      expect(orders.reduce((int a, int b) => a > b ? a : b), 114);
      expect(quran.surah(96).revelationOrder, 1); // Al-'Alaq came first.
      expect(quran.byRevelation.first.number, 96);
    });

    test('thirty juz, each starting where the mushaf says', () {
      final List<Juz> juzs = quran.juzs;
      expect(juzs.length, 30);
      expect(juzs.first.firstAyah.key, '1:1');
      expect(juzs[1].firstAyah.key, '2:142');
      expect(juzs.last.firstAyah.key, '78:1');
      expect(juzs.last.firstPage, 582);
      expect(juzs.first.arabicName, 'الجزء الأول');
    });
  });

  group('Tafsir text', () {
    test('drops the markup and keeps the paragraphs', () {
      expect(
        TafsirService.plainText(
          '<h2>Title</h2><p>One &amp; two.</p><p>Three<br/>four.</p>',
        ),
        'Title\n\nOne & two.\n\nThree\nfour.',
      );
    });
  });
}
