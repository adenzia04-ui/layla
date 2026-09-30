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
/// the way the mushaf does: every space-separated token, pause marks
/// included.
@immutable
class WordSpan {
  const WordSpan(this.position, this.start, this.end);

  final int position;
  final int start;
  final int end;
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
  /// Between two words the earlier one stays lit, so the light never
  /// blinks out on a breath. It does go out when the voice is somewhere
  /// the timings cannot follow: [_afterWord] past a word's end in the
  /// middle of an ayah — a reciter repeating an earlier phrase, which the
  /// source data leaves untimed — or [_afterLast] past the last word, so a
  /// held final word keeps its light to the end of the breath.
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
    final int grace = at == spans.length - 1 ? _afterLast : _afterWord;
    return ms > s.end + grace ? 0 : s.position;
  }

  static const int _afterWord = 2500;
  static const int _afterLast = 2000;

  /// `assets/quran/timing/<voice>.json`: `{"1:1": [[word, start, end], …]}`,
  /// one entry per word of our text, built by `tool/fetch_segments.py`.
  /// A two-number entry is read as `[start, end]` with the word taken from
  /// its place in the list.
  static VoiceTiming parse(String voice, String json) {
    final Map<String, Object?> raw = jsonDecode(json) as Map<String, Object?>;
    final Map<String, List<WordSpan>> out = <String, List<WordSpan>>{};
    raw.forEach((String key, Object? value) {
      final List<Object?> list = value! as List<Object?>;
      // Kept in time order whatever the file says. [wordAt] walks the list
      // and stops at the first word that starts later, so one entry out of
      // order would freeze the light on an early word for the rest of the
      // ayah — which is exactly how Sudais looked when his timings were
      // sorted as text.
      out[key] = <WordSpan>[
        for (int i = 0; i < list.length; i++)
          () {
            final List<Object?> pair = list[i]! as List<Object?>;
            // The API has been known to send a millisecond as text.
            int at(int j) => (pair[j] is num)
                ? (pair[j]! as num).toInt()
                : int.parse('${pair[j]}');
            return WordSpan(
              pair.length > 2 ? at(0) : i + 1,
              at(pair.length - 2),
              at(pair.length - 1),
            );
          }(),
      ]..sort((WordSpan a, WordSpan b) => a.start.compareTo(b.start));
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
