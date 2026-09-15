import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/tasbih/domain/dhikr.dart';
import 'package:noor/features/tasbih/domain/quran_passages.dart';
import 'package:noor/features/tasbih/domain/sunnah_routine.dart';

/// These checksums are the point of this file.
///
/// The Arabic in `quran_passages.dart` was fetched from api.quran.com and
/// cross-checked against api.alquran.cloud before being written. Nobody should
/// ever hand-edit it — a single altered harakah would be silent, and a
/// reviewer skimming a diff of unfamiliar script would not catch it. If one of
/// these fails, the text changed: re-fetch and re-verify, do not update the
/// hash to match.
void main() {
  const Map<String, String> verified = <String, String>{
    'Al-Ikhlas': 'f61d06afe06b58fb',
    'Al-Falaq': '4d61cef3563c9f56',
    'An-Nas': '5c73e1db330d061b',
    'Ayat al-Kursi': '11be93994fadd008',
  };

  final List<Dhikr> passages = <Dhikr>[
    QuranPassages.ikhlas,
    QuranPassages.falaq,
    QuranPassages.nas,
    QuranPassages.ayatAlKursi,
  ];

  test('the Arabic is byte-for-byte what was fetched and cross-checked', () {
    for (final Dhikr d in passages) {
      final String sum = crypto.sha256
          .convert(utf8.encode(d.arabic))
          .toString()
          .substring(0, 16);
      expect(
        sum,
        verified[d.name],
        reason:
            '${d.name} has been altered since it was verified. Re-fetch '
            'and re-verify against two sources — do not update this hash.',
      );
    }
  });

  /// Reads the characters a TrueType font can actually draw, from its cmap.
  Set<int> coveredBy(String path) {
    final ByteData d = ByteData.sublistView(File(path).readAsBytesSync());
    int? cmapOff;
    final int tables = d.getUint16(4);
    for (int i = 0; i < tables; i++) {
      final int rec = 12 + 16 * i;
      final String tag = String.fromCharCodes(<int>[
        for (int k = 0; k < 4; k++) d.getUint8(rec + k),
      ]);
      if (tag == 'cmap') cmapOff = d.getUint32(rec + 8);
    }
    final Set<int> out = <int>{};
    final int subtables = d.getUint16(cmapOff! + 2);
    for (int i = 0; i < subtables; i++) {
      final int t = cmapOff + d.getUint32(cmapOff + 4 + 8 * i + 4);
      final int format = d.getUint16(t);
      if (format == 4) {
        final int segX2 = d.getUint16(t + 6);
        final int segs = segX2 ~/ 2;
        for (int s = 0; s < segs; s++) {
          final int end = d.getUint16(t + 14 + 2 * s);
          final int start = d.getUint16(t + 16 + segX2 + 2 * s);
          if (start == 0xFFFF && end == 0xFFFF) continue;
          for (int c = start; c <= end; c++) {
            out.add(c);
          }
        }
      } else if (format == 12) {
        final int groups = d.getUint32(t + 12);
        for (int g = 0; g < groups; g++) {
          final int o = t + 16 + 12 * g;
          for (int c = d.getUint32(o); c <= d.getUint32(o + 4); c++) {
            out.add(c);
          }
        }
      }
    }
    return out;
  }

  test('the bundled font can draw every character of every passage', () {
    // This is not hypothetical. The other Madinah source encodes the open
    // tanwin as U+065E, which Amiri Quran has no glyph for — shipping it would
    // have put an empty box in the middle of Ayat al-Kursi, and nothing in the
    // widget tests would have failed.
    String hex(int r) =>
        'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}';

    final Set<int> arabicFont = coveredBy(
      'assets/fonts/AmiriQuran-Regular.ttf',
    );
    final Set<int> latinFont = coveredBy('assets/fonts/Inter.ttf');

    for (final Dhikr d in passages) {
      final Set<int> noArabic = d.arabic.runes
          .where((int r) => r != 0x20 && !arabicFont.contains(r))
          .toSet();
      expect(
        noArabic,
        isEmpty,
        reason:
            '${d.name}: Amiri Quran cannot draw '
            '${noArabic.map(hex).join(', ')}',
      );

      // The transliteration is the same trap in Latin: diacritics and circled
      // numerals live well outside the usual range, and a font missing one
      // would show an empty box rather than fail anything.
      final Set<int> noLatin = d.spoken.runes
          .where((int r) => r != 0x20 && !latinFont.contains(r))
          .toSet();
      expect(
        noLatin,
        isEmpty,
        reason: '${d.name}: Inter cannot draw ${noLatin.map(hex).join(', ')}',
      );
    }
  });

  test('each ayah is numbered in the transliteration', () {
    // The source gives one string per ayah with no terminal punctuation, so an
    // earlier join on a bare space ran al-Ikhlas together as "…kufuwan ahad
    // Allah hus-samad Lam yalid…", capitals landing mid-sentence with nothing
    // to break on. Every ayah now carries its own number instead.
    const Map<String, int> ayahs = <String, int>{
      'Al-Ikhlas': 4,
      'Al-Falaq': 5,
      'An-Nas': 6,
      'Ayat al-Kursi': 1,
    };
    for (final Dhikr d in passages) {
      final int count = ayahs[d.name]!;
      final int markers = RegExp(
        r'[\u2460-\u2473]',
      ).allMatches(d.spoken).length;
      if (count == 1) {
        expect(
          markers,
          0,
          reason: '${d.name} is one ayah; a number says nothing',
        );
      } else {
        expect(
          markers,
          count,
          reason:
              '${d.name} has $count ayahs but $markers markers — they '
              'have run together',
        );
      }
    }
  });

  test('the transliteration is the scholarly one, not flat ASCII', () {
    // The point of switching sources. Without the diacritics there is no way
    // to tell sad from seen, or a long vowel from a short one.
    for (final Dhikr d in passages) {
      expect(
        RegExp('[ḥṣṭḍẓʿāīū]').hasMatch(d.spoken),
        isTrue,
        reason: '${d.name} lost its diacritics',
      );
    }
  });

  test('every passage carries its reference and both readings', () {
    for (final Dhikr d in passages) {
      expect(d.source, isNotNull, reason: '${d.name} has no surah reference');
      expect(d.arabic, isNotEmpty);
      expect(d.transliteration, isNotNull);
      expect(d.meaning, isNotEmpty);
    }
  });

  test('before sleep protection runs Quran first, then the tasbih', () {
    const SunnahRoutine r = SunnahRoutine.beforeSleepProtection;
    expect(r.stages.map((Dhikr d) => d.name).toList(), <String>[
      'Ayat al-Kursi',
      'Al-Ikhlas',
      'Al-Falaq',
      'An-Nas',
      'SubhanAllah',
      'Alhamdulillah',
      'Allahu Akbar',
    ]);
    // 1 + 3 + 3 + 3 + 33 + 33 + 34
    expect(r.total, 110);
    expect(r.stages.first.isRecited, isTrue, reason: 'Kursi is read once');
    expect(r.stages.last.isRecited, isFalse, reason: 'the takbir is counted');
  });

  test('the Quran stages are recited and the tasbih stages are counted', () {
    const SunnahRoutine r = SunnahRoutine.beforeSleepProtection;
    for (final Dhikr d in r.stages) {
      expect(
        d.isRecited,
        d.source != null,
        reason: '${d.name}: Quran is read from the text, dhikr is tapped out',
      );
    }
  });
}
