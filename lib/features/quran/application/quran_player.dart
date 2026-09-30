import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recitation_cache.dart';
import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../domain/quran_data.dart';
import '../domain/quran_queue.dart';
import '../domain/reciters.dart';
import 'quran_prefs.dart';

/// The ayah being recited from [surah], if the player is on that surah in
/// the chosen voice. Null otherwise, so a reader never highlights an ayah
/// for a recitation that is not its own.
NowPlaying? surahNowPlaying(NowPlaying? now, int surah, Reciter reciter) =>
    now != null && now.owner == surahOwner(surah, reciter) ? now : null;

/// The ayah number inside [now]'s group key, `2:255` → 255.
int ayahOf(NowPlaying now) =>
    int.tryParse(now.track.group.split(':').last) ?? 1;

/// Starts [surah] at [ayah] with the remembered reciter, mode, repeat count
/// and loop setting. Nothing happens without a player.
///
/// Recordings already on the device play from the file; the rest stream
/// and are fetched into the cache from this ayah onwards, so the next
/// listen — and the repeats of this one — need no signal.
Future<void> playSurah(
  WidgetRef ref, {
  required Quran quran,
  required int surah,
  int ayah = 1,
}) async {
  final RecitationHandler? handler = ref.read(recitationHandlerProvider);
  if (handler == null) return;
  final Reciter reciter = ref.read(reciterProvider);
  final RecitationCache? cache = RecitationCache.instance;
  final List<RecitationTrack> tracks = surahTracks(
    quran,
    surah,
    reciter: reciter,
    mode: ref.read(playModeProvider),
    repeat: ref.read(ayahRepeatProvider),
    localFile: cache?.pathIfCached,
  );
  final int start = trackIndexOf(tracks, ayah);
  if (start < 0) return;
  await ref.read(lastReadProvider.notifier).set('$surah:$ayah');
  await handler.load(
    tracks,
    owner: surahOwner(surah, reciter),
    start: start,
    loop: ref.read(loopSurahProvider),
  );
  cache?.prefetch(<Uri>[
    for (final RecitationTrack t in tracks.skip(start))
      if (t.file == null && t.url != null) t.url!,
    for (final RecitationTrack t in tracks.take(start))
      if (t.file == null && t.url != null) t.url!,
  ]);
}
