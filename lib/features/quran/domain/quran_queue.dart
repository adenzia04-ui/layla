import '../../../core/audio/recitation_handler.dart';
import 'quran_data.dart';
import 'reciters.dart';

/// How a surah is played.
enum PlayMode {
  /// Straight through, each ayah once.
  surah,

  /// Each ayah the chosen number of times, then the next — for memorising.
  ayahByAyah,
}

/// The queue owner key for a surah, so a reader can tell its own recitation
/// from another surah's or from a dua.
String surahOwner(int surah, Reciter reciter) => 'quran:$surah:${reciter.id}';

/// The tracks for [surah], from its first ayah, in [reciter]'s voice.
///
/// In [PlayMode.ayahByAyah] every ayah is repeated [repeat] times in a row
/// (held to 1–10); in [PlayMode.surah] once. Each ayah is its own group, so
/// next and previous on the lock screen move by ayah. The basmalah is not
/// prepended: the reciters' files for ayah 1 already open with it where the
/// mushaf prints it.
List<RecitationTrack> surahTracks(
  Quran quran,
  int surah, {
  required Reciter reciter,
  required PlayMode mode,
  required int repeat,
}) {
  final Surah s = quran.surah(surah);
  final int passes = mode == PlayMode.ayahByAyah ? repeat.clamp(1, 10) : 1;
  return <RecitationTrack>[
    for (final Ayah a in quran.ayahsOf(surah))
      for (int pass = 1; pass <= passes; pass++)
        RecitationTrack(
          id: '${a.key}#$pass',
          group: a.key,
          title: '${s.name} · Ayah ${a.number}',
          subtitle: passes > 1
              ? '${reciter.name} · $pass of $passes'
              : reciter.name,
          album: '${s.name} (${s.meaning})',
          url: reciter.url(surah, a.number),
          pass: pass,
          passes: passes,
        ),
  ];
}

/// Where [ayah] starts in a queue built by [surahTracks], or -1.
int trackIndexOf(List<RecitationTrack> tracks, int ayah) => tracks.indexWhere(
  (RecitationTrack t) => t.group.endsWith(':$ayah') && t.pass == 1,
);
