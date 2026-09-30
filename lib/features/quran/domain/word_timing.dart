import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The voices whose recordings come with word timings.
///
/// The timings are quran.com's, made on the very same files everyayah
/// serves — checked byte for byte — so a word lights exactly as it is
/// heard. Husary's file there is a lower-bitrate encode of the same
/// recording, which drifts under a tenth of a second across an ayah.
const Set<String> timedVoices = <String>{
  'alafasy',
  'abdulbasit',
  'sudais',
  'husary',
  'shuraym',
  'minshawi',
  'shatri',
  'rifai',
};

/// When one word is heard, in milliseconds from the start of its ayah's
/// recording. [position] is the word's 1-based place in the ayah, counting
/// words only — a lone pause mark (ۖ ۗ ۚ …) is not a word.
@immutable
class WordSpan {
  const WordSpan(
    this.position,
    this.start,
    this.end, {
    this.thenRepeat = false,
  });

  final int position;
  final int start;
  final int end;

  /// After this word the reciter goes back over earlier words before the
  /// next one — a repeat the timings do not follow. The light goes out at
  /// [end] instead of waiting for the next word.
  final bool thenRepeat;
}

/// Every ayah's word timings in one voice, keyed `2:255`.
class VoiceTiming {
  const VoiceTiming._(this.voice, this._ayahs);

  final String voice;
  final Map<String, List<WordSpan>> _ayahs;

  List<WordSpan> of(String ayahKey) => _ayahs[ayahKey] ?? const <WordSpan>[];

  int get ayahCount => _ayahs.length;

  /// The word sounding at [ms] into [ayahKey]'s recording, as a 1-based
  /// position, or 0 when no word is.
  ///
  /// Between two words the earlier one stays lit, so the light never blinks
  /// out on a breath — however long the breath. It goes out only where the
  /// recording was heard to hold speech the timings cannot follow: a word
  /// marked [WordSpan.thenRepeat] goes dark [_afterRepeat] past its end,
  /// and the last word [_afterLast] past its end, so a held final word
  /// keeps its light to the end of the breath.
  int wordAt(String ayahKey, int ms) {
    final List<WordSpan> spans = of(ayahKey);
    if (spans.isEmpty || ms < spans.first.start) return 0;
    int at = 0;
    for (int i = 1; i < spans.length; i++) {
      if (spans[i].start <= ms) {
        at = i;
      } else {
        break;
      }
    }
    final WordSpan s = spans[at];
    if (at == spans.length - 1) {
      return ms > s.end + _afterLast ? 0 : s.position;
    }
    if (s.thenRepeat && ms > s.end + _afterRepeat) return 0;
    return s.position;
  }

  static const int _afterRepeat = 250;
  static const int _afterLast = 2000;

  /// `assets/quran/timing/<voice>.json`: `{"1:1": [[word, start, end], …]}`,
  /// one entry per word of our text, built by `tool/fetch_segments.py`; a
  /// fourth number, 1, marks [WordSpan.thenRepeat]. A two-number entry is
  /// read as `[start, end]` and numbered by time order. A malformed entry
  /// is skipped rather than failing the voice.
  static VoiceTiming parse(String voice, String json) {
    final Map<String, Object?> raw = jsonDecode(json) as Map<String, Object?>;
    final Map<String, List<WordSpan>> out = <String, List<WordSpan>>{};
    int? number(Object? v) => switch (v) {
      final num n => n.toInt(),
      final String t => num.tryParse(t)?.toInt(),
      _ => null,
    };
    raw.forEach((String key, Object? value) {
      if (value is! List) return;
      final List<List<int>> rows = <List<int>>[];
      bool positioned = true;
      for (final Object? entry in value) {
        if (entry is! List || entry.length < 2) continue;
        final List<int?> n = entry.map(number).toList();
        if (n.any((int? x) => x == null)) continue;
        if (entry.length == 2) positioned = false;
        rows.add(n.cast<int>());
      }
      // Kept in time order whatever the file says. [wordAt] walks the list
      // and stops at the first word that starts later, so one entry out of
      // order would freeze the light on an early word for the rest of the
      // ayah — which is exactly how Sudais looked when his timings were
      // sorted as text.
      final List<WordSpan> spans = <WordSpan>[
        for (int i = 0; i < rows.length; i++)
          rows[i].length == 2
              ? WordSpan(i + 1, rows[i][0], rows[i][1])
              : WordSpan(
                  rows[i][0],
                  rows[i][1],
                  rows[i][2],
                  thenRepeat: rows[i].length > 3 && rows[i][3] == 1,
                ),
      ]..sort((WordSpan a, WordSpan b) => a.start.compareTo(b.start));
      out[key] = positioned
          ? spans
          : <WordSpan>[
              for (int i = 0; i < spans.length; i++)
                WordSpan(i + 1, spans[i].start, spans[i].end),
            ];
    });
    return VoiceTiming._(voice, out);
  }

  static Future<VoiceTiming> load(String voice) async {
    final String json = await rootBundle.loadString(
      'assets/quran/timing/$voice.json',
    );
    return compute(_parseIsolate, <String>[voice, json]);
  }

  static VoiceTiming _parseIsolate(List<String> args) =>
      parse(args[0], args[1]);
}
