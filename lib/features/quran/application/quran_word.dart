import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../domain/mushaf_glyphs.dart';
import '../domain/word_timing.dart';
import 'quran_player.dart';

/// The word being recited, as the reader and the mushaf see it.
@immutable
class SpokenWord {
  const SpokenWord({
    required this.surah,
    required this.ayah,
    required this.word,
  });

  final int surah;
  final int ayah;

  /// 1-based, words only (pause marks not counted); 0 when the ayah is
  /// known but the word is not — before the first word, or in a voice
  /// without timings.
  final int word;

  String get ayahKey => '$surah:$ayah';

  @override
  bool operator ==(Object other) =>
      other is SpokenWord &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.word == word;

  @override
  int get hashCode => Object.hash(surah, ayah, word);
}

/// A voice's word timings, loaded once from the bundle. An untimed voice
/// resolves to null rather than failing.
final FutureProviderFamily<VoiceTiming?, String> voiceTimingProvider =
    FutureProvider.family<VoiceTiming?, String>((Ref ref, String voice) {
      if (!timedVoices.contains(voice)) return Future<VoiceTiming?>.value();
      return VoiceTiming.load(voice);
    });

/// The page boxes for every word, loaded once.
final FutureProvider<MushafGlyphs> glyphsProvider =
    FutureProvider<MushafGlyphs>((Ref ref) => MushafGlyphs.load());

/// The player's position, often enough to follow a word.
final StreamProvider<Duration> finePositionProvider = StreamProvider<Duration>((
  Ref ref,
) {
  final RecitationHandler? h = ref.watch(recitationHandlerProvider);
  return h == null ? const Stream<Duration>.empty() : h.finePosition;
});

/// What is being recited right now, down to the word where the voice has
/// timings; the ayah alone where it does not; null when the Qur'an is not
/// what is playing.
///
/// Screens watch this with a `select`, so only the card or the page that
/// holds the word repaints as it moves.
final Provider<SpokenWord?> spokenWordProvider = Provider<SpokenWord?>((
  Ref ref,
) {
  final NowPlaying? now = ref.watch(nowPlayingProvider).valueOrNull;
  if (now == null || !now.owner.startsWith('quran:')) return null;
  final int surah = int.tryParse(now.owner.substring(6)) ?? 0;
  final int ayah = ayahOf(now);
  if (surah == 0 || ayah == 0) return null;
  final String? voice = now.track.voice;
  final VoiceTiming? timing = voice == null
      ? null
      : ref.watch(voiceTimingProvider(voice)).valueOrNull;
  if (timing == null) return SpokenWord(surah: surah, ayah: ayah, word: 0);
  final Duration at =
      ref.watch(finePositionProvider).valueOrNull ?? Duration.zero;
  return SpokenWord(
    surah: surah,
    ayah: ayah,
    word: timing.wordAt('$surah:$ayah', at.inMilliseconds),
  );
});
