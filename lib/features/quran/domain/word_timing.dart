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
  /// position, or 0 before the first word and after the last. Between two
  /// words the earlier one is kept, so the light never blinks out on a
  /// breath.
  int wordAt(String ayahKey, int ms) {
    final List<WordSpan> spans = of(ayahKey);
    if (spans.isEmpty || ms < spans.first.start) return 0;
    int current = 0;
    for (final WordSpan s in spans) {
      if (s.start <= ms) {
        current = s.position;
      } else {
        break;
      }
    }
    if (ms > spans.last.end + 400) return 0;
    return current;
  }

  /// `assets/quran/timing/<voice>.json`: `{"1:1": [[start, end], …], …}`,
  /// each ayah's words in order. A missing word has no entry, and the
  /// positions are recovered from the order.
  static VoiceTiming parse(String voice, String json) {
    final Map<String, Object?> raw = jsonDecode(json) as Map<String, Object?>;
    final Map<String, List<WordSpan>> out = <String, List<WordSpan>>{};
    raw.forEach((String key, Object? value) {
      final List<Object?> list = value! as List<Object?>;
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
