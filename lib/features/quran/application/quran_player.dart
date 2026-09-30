import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recitation_cache.dart';
import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../domain/quran_data.dart';
import '../domain/quran_queue.dart';
import '../domain/reciters.dart';
import 'quran_prefs.dart';

/// The recitation of [surah], if that is what the player is on. Null
/// otherwise, so a reader never highlights an ayah for a recitation that is
/// not its own.
NowPlaying? surahNowPlaying(NowPlaying? now, int surah) =>
    now != null && now.owner == surahOwner(surah) ? now : null;

/// The ayah number inside [now]'s group key, `2:255` → 255. Zero for a
/// whole-surah voice, which has no ayah to point at.
int ayahOf(NowPlaying now) =>
    int.tryParse(now.track.group.split(':').last) ?? 0;

/// Starts [surah] at [ayah] with the remembered reciter, mode, repeat count
/// and loop setting. Nothing happens without a player.
///
/// Recordings already on the device play from the file; the rest stream,
/// and the few ahead are fetched into the cache so the next ayahs — and the
/// repeats of this one — need no signal.
Future<void> playSurah(
  WidgetRef ref, {
  required Quran quran,
  required int surah,
  int ayah = 1,
}) async {
  final RecitationHandler? handler = ref.read(recitationHandlerProvider);
  if (handler == null) return;
  final Reciter reciter = ref.read(reciterProvider);
  final List<RecitationTrack> tracks = _tracksFor(ref, quran, surah, reciter);
  final int start = trackIndexOf(tracks, ayah);
  if (start < 0) return;
  await ref.read(lastReadProvider.notifier).set('$surah:$ayah');
  await handler.load(
    tracks,
    owner: surahOwner(surah),
    start: start,
    loop: ref.read(loopSurahProvider),
  );
  _lastPrefetch = null;
  prefetchAhead(ref, quran: quran, surah: surah, ayah: ayah);
}

List<RecitationTrack> _tracksFor(
  WidgetRef ref,
  Quran quran,
  int surah,
  Reciter reciter,
) => surahTracks(
  quran,
  surah,
  reciter: reciter,
  mode: ref.read(playModeProvider),
  repeat: ref.read(ayahRepeatProvider),
  localFile: RecitationCache.instance?.pathIfCached,
);

/// How many ayahs ahead of the one sounding are fetched. A few, not the
/// surah: Al-Baqarah in a 192 kbps voice is over a hundred megabytes, and
/// nobody asked for that on a phone signal — downloading the surah is its
/// own, deliberate action. Called again as the reciter moves, so the
/// window slides.
const int _prefetchWindow = 6;
String? _lastPrefetch;

void prefetchAhead(
  WidgetRef ref, {
  required Quran quran,
  required int surah,
  required int ayah,
}) {
  final RecitationCache? cache = RecitationCache.instance;
  if (cache == null) return;
  final Reciter reciter = ref.read(reciterProvider);
  final String key = '${surahOwner(surah)}:${reciter.id}:$ayah';
  if (key == _lastPrefetch) return;
  _lastPrefetch = key;
  final List<RecitationTrack> tracks = _tracksFor(ref, quran, surah, reciter);
  final int from = trackIndexOf(tracks, ayah);
  if (from < 0) return;
  cache.cancelPending();
  cache.prefetch(<Uri>[
    for (final RecitationTrack t in tracks.skip(from).take(_prefetchWindow))
      if (t.file == null && t.url != null) t.url!,
  ]);
}

/// The listening settings as one value, so a screen can tell whether the
/// options sheet changed anything worth restarting for.
(String, PlayMode, int, bool) listeningSettings(WidgetRef ref) => (
  ref.read(reciterProvider).id,
  ref.read(playModeProvider),
  ref.read(ayahRepeatProvider),
  ref.read(loopSurahProvider),
);
