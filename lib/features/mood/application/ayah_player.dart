import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

/// Recitation in the voice of Mishary Rashid Alafasy.
///
/// A card usually shows part of a verse, so the recitation is cut to those
/// words: Quran.com publishes word-by-word timings for Alafasy's chapter
/// recordings, and the card's Arabic is matched against the verse's words to
/// find where its span starts and ends. When the words cannot be matched, or
/// the timings cannot be fetched, the whole verse plays from EveryAyah as it
/// always did.
///
/// One player for the app, one passage at a time: tapping a second card stops
/// the first. A recitation that fails to start simply stops, and the button
/// returns to play.
final Provider<AyahPlayer> ayahPlayerProvider = Provider<AyahPlayer>((Ref ref) {
  final AyahPlayer player = AyahPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// The id of the passage being recited, or null.
final StateProvider<String?> recitingProvider = StateProvider<String?>(
  (Ref ref) => null,
);

class AyahPlayer {
  final AudioPlayer _player = AudioPlayer();
  String? _current;

  /// Chapter timings, fetched once per chapter per launch.
  final Map<int, _ChapterTimings> _timings = <int, _ChapterTimings>{};

  static String url({required int chapter, required int verse}) {
    final String c = chapter.toString().padLeft(3, '0');
    final String v = verse.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/Alafasy_128kbps/$c$v.mp3';
  }

  /// Plays the words of [excerpt] from verse [chapter]:[verse], or stops if
  /// [key] is already playing. Reports what is playing through [onChange].
  Future<void> toggle({
    required String key,
    required int chapter,
    required int verse,
    String? excerpt,
    required void Function(String?) onChange,
  }) async {
    if (_current == key) {
      _current = null;
      onChange(null);
      await _player.stop();
      return;
    }
    _current = key;
    onChange(key);
    try {
      await _player.stop();
      final _Clip? clip = excerpt == null
          ? null
          : await _clipFor(chapter: chapter, verse: verse, excerpt: excerpt);
      if (_current != key) return;
      if (clip != null) {
        await _player.setAudioSource(
          ClippingAudioSource(
            start: clip.start,
            end: clip.end,
            child: AudioSource.uri(Uri.parse(clip.url)),
          ),
        );
      } else {
        await _player.setUrl(url(chapter: chapter, verse: verse));
      }
      // Completes when the passage ends, or when stop() is called.
      await _player.play();
    } on Object catch (e) {
      debugPrint('Layla Pro: recitation stopped ($e)');
    }
    if (_current == key) {
      _current = null;
      onChange(null);
    }
  }

  Future<void> stop() async {
    _current = null;
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }

  // ── Finding the words ────────────────────────────────────────────────

  /// The card's Arabic is in standard spelling; the Uthmani script differs
  /// in ways that break a word-by-word comparison (يايها for يا أيها, الصلوة
  /// for الصلاة). So the words are fetched in standard spelling, every word
  /// of the verse is reduced to a skeleton and joined into one string, the
  /// card's skeleton is found inside it, and the offsets are mapped back to
  /// the first and last word. A card that runs into the next verse is
  /// followed there; a card whose alifs still differ (a dagger alif written
  /// out, ذالك for ذلك) is matched once more with every alif removed.
  Future<_Clip?> _clipFor({
    required int chapter,
    required int verse,
    required String excerpt,
  }) async {
    try {
      final _ChapterTimings timings = _timings[chapter] ??= await _fetchTimings(
        chapter,
      );
      if (!timings.verses.containsKey('$chapter:$verse')) return null;

      final List<_Word> words = <_Word>[];
      _Span? span;
      for (int v = verse; v < verse + 3 && span == null; v++) {
        final List<_Word> next = await _fetchWords(chapter, v);
        if (next.isEmpty) break;
        words.addAll(next);
        span =
            _locate(words, excerpt, loose: false) ??
            _locate(words, excerpt, loose: true);
      }
      if (span == null) return null;

      final _VerseTiming? vFirst =
          timings.verses['$chapter:${span.first.verse}'];
      final _VerseTiming? vLast = timings.verses['$chapter:${span.last.verse}'];
      if (vFirst == null || vLast == null) return null;

      final bool wholeStart = span.first.position == 1;
      final bool wholeEnd =
          span.last.position ==
          words.where((_Word w) => w.verse == span!.last.verse).length;
      final Duration? start = wholeStart
          ? vFirst.from
          : vFirst.wordStart(span.first.position);
      final Duration? end = wholeEnd
          ? vLast.to
          : vLast.wordEnd(span.last.position);
      if (start == null || end == null || end <= start) return null;
      debugPrint(
        'Layla Pro: reciting $chapter:${span.first.verse} words '
        '${span.first.position}-${span.last.position} '
        '(${span.last.verse}), ${(end - start).inMilliseconds} ms',
      );
      // A breath either side, so the cut never clips a consonant.
      return _Clip(
        timings.url,
        start - const Duration(milliseconds: 120),
        end + const Duration(milliseconds: 220),
      );
    } catch (e) {
      debugPrint('Layla Pro: could not cut the recitation ($e)');
      return null;
    }
  }

  static _Span? _locate(
    List<_Word> words,
    String excerpt, {
    required bool loose,
  }) {
    final String want = _norm(excerpt, loose: loose);
    if (want.isEmpty) return null;
    final StringBuffer joined = StringBuffer();
    final List<int> starts = <int>[];
    for (final _Word w in words) {
      starts.add(joined.length);
      joined.write(_norm(w.text, loose: loose));
    }
    final int at = joined.toString().indexOf(want);
    if (at < 0) return null;
    final int endAt = at + want.length - 1;
    _Word? first;
    _Word? last;
    for (int i = 0; i < words.length; i++) {
      final int wordEnd = i + 1 < starts.length ? starts[i + 1] : joined.length;
      if (first == null && wordEnd > at) first = words[i];
      if (wordEnd > endAt) {
        last = words[i];
        break;
      }
    }
    if (first == null || last == null) return null;
    return _Span(first, last);
  }

  static Map<String, String> get _headers => const <String, String>{
    'User-Agent': 'LaylaPro/1.0 (iOS)',
    'Accept': 'application/json',
  };

  Future<_ChapterTimings> _fetchTimings(int chapter) async {
    final http.Response res = await http
        .get(
          Uri.parse(
            'https://api.qurancdn.com/api/qdc/audio/reciters/7/audio_files'
            '?chapter=$chapter&segments=true',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('timings ${res.statusCode}');
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    final Map<String, dynamic> file =
        (json['audio_files'] as List<dynamic>).first as Map<String, dynamic>;
    final Map<String, _VerseTiming> verses = <String, _VerseTiming>{};
    for (final dynamic v in file['verse_timings'] as List<dynamic>) {
      final Map<String, dynamic> m = v as Map<String, dynamic>;
      final Map<int, (int, int)> segs = <int, (int, int)>{};
      for (final dynamic s in (m['segments'] as List<dynamic>? ?? const [])) {
        final List<dynamic> t = s as List<dynamic>;
        if (t.length >= 3) {
          // A reciter sometimes repeats a phrase, so a position can appear
          // twice: keep the earliest start and the latest end, and the cut
          // includes the repeat rather than half of it.
          final int pos = (t[0] as num).toInt();
          final int from = (t[1] as num).toInt();
          final int to = (t[2] as num).toInt();
          final (int, int)? was = segs[pos];
          segs[pos] = was == null
              ? (from, to)
              : (from < was.$1 ? from : was.$1, to > was.$2 ? to : was.$2);
        }
      }
      verses[m['verse_key'] as String] = _VerseTiming(
        from: Duration(milliseconds: (m['timestamp_from'] as num).toInt()),
        to: Duration(milliseconds: (m['timestamp_to'] as num).toInt()),
        segments: segs,
      );
    }
    return _ChapterTimings(url: file['audio_url'] as String, verses: verses);
  }

  /// The verse's words in standard spelling; empty past the end of the surah.
  Future<List<_Word>> _fetchWords(int chapter, int verse) async {
    final http.Response res = await http
        .get(
          Uri.parse(
            'https://api.quran.com/api/v4/verses/by_key/$chapter:$verse'
            '?words=true&word_fields=text_imlaei_simple',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode == 404) return const <_Word>[];
    if (res.statusCode != 200) throw Exception('words ${res.statusCode}');
    final Map<String, dynamic> json =
        jsonDecode(res.body) as Map<String, dynamic>;
    final List<dynamic> words =
        (json['verse'] as Map<String, dynamic>)['words'] as List<dynamic>;
    return <_Word>[
      for (final dynamic w in words)
        if ((w as Map<String, dynamic>)['char_type_name'] != 'end')
          _Word(
            verse: verse,
            position: (w['position'] as num).toInt(),
            text: (w['text_imlaei_simple'] ?? '') as String,
          ),
    ];
  }

  /// Arabic reduced to its skeleton: no marks, no elongation, one alif, one
  /// ya, no hamza carriers. With [loose], no alif at all.
  static String _norm(String s, {required bool loose}) {
    String out = s
        .replaceAll(RegExp('[ً-ٰٟۖ-ۭـۡ]'), '')
        .replaceAll(RegExp('[ٱآأإ]'), 'ا')
        .replaceAll(RegExp('[ىی]'), 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ء', '')
        .replaceAll(RegExp('[^ء-ي]'), '');
    if (loose) out = out.replaceAll('ا', '');
    return out;
  }
}

class _Word {
  const _Word({
    required this.verse,
    required this.position,
    required this.text,
  });

  final int verse;

  /// 1-based, as in the timing segments.
  final int position;
  final String text;
}

class _Span {
  const _Span(this.first, this.last);

  final _Word first;
  final _Word last;
}

class _ChapterTimings {
  const _ChapterTimings({required this.url, required this.verses});

  final String url;
  final Map<String, _VerseTiming> verses;
}

class _VerseTiming {
  const _VerseTiming({
    required this.from,
    required this.to,
    required this.segments,
  });

  final Duration from;
  final Duration to;

  /// Word position (1-based) → (start ms, end ms).
  final Map<int, (int, int)> segments;

  Duration? wordStart(int position) {
    final (int, int)? s = segments[position];
    return s == null ? null : Duration(milliseconds: s.$1);
  }

  Duration? wordEnd(int position) {
    final (int, int)? s = segments[position];
    return s == null ? null : Duration(milliseconds: s.$2);
  }
}

class _Clip {
  const _Clip(this.url, this.start, this.end);

  final String url;
  final Duration start;
  final Duration end;
}
