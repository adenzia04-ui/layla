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
/// from another surah's or from a dua. Deliberately not the voice: picking
/// another reciter in the options sheet must not make the screen lose sight
/// of the recitation still sounding — it restarts in the new voice instead.
String surahOwner(int surah) => 'quran:$surah';

/// The group key of a whole-surah track, so the screens know there is no
/// ayah to highlight.
String wholeSurahGroup(int surah) => '$surah:0';

/// The tracks for [surah] in [reciter]'s voice.
///
/// One per ayah for a per-ayah voice: in [PlayMode.ayahByAyah] every ayah
/// is read [repeat] times (held to 1–10) before the next; in
/// [PlayMode.surah] once. A whole-surah voice gives one track for the
/// surah, read once — there is no ayah to repeat. The basmalah is not
/// prepended: the reciters' files for ayah 1 already open with it where
/// the mushaf prints it.
///
/// [localFile] answers with a path when the recording is already on the
/// device, so it plays from there instead of the network.
List<RecitationTrack> surahTracks(
  Quran quran,
  int surah, {
  required Reciter reciter,
  required PlayMode mode,
  required int repeat,
  String? Function(Uri url)? localFile,
}) {
  final Surah s = quran.surah(surah);
  if (!reciter.perAyah) {
    final Uri url = reciter.surahUrl(surah);
    return <RecitationTrack>[
      RecitationTrack(
        id: wholeSurahGroup(surah),
        group: wholeSurahGroup(surah),
        title: s.name,
        subtitle: reciter.name,
        album: '${s.name} (${s.meaning})',
        url: url,
        file: localFile?.call(url),
        voice: reciter.id,
      ),
    ];
  }
  final int passes = mode == PlayMode.ayahByAyah ? repeat.clamp(1, 10) : 1;
  return <RecitationTrack>[
    for (final Ayah a in quran.ayahsOf(surah))
      () {
        final Uri url = reciter.url(surah, a.number);
        return RecitationTrack(
          id: a.key,
          group: a.key,
          title: '${s.name} · Ayah ${a.number}',
          subtitle: reciter.name,
          album: '${s.name} (${s.meaning})',
          url: url,
          file: localFile?.call(url),
          passes: passes,
          voice: reciter.id,
        );
      }(),
  ];
}

/// Where [ayah] sits in a queue built by [surahTracks], or -1. A whole-surah
/// queue has one track, and every ayah is in it.
int trackIndexOf(List<RecitationTrack> tracks, int ayah) {
  if (tracks.length == 1 && tracks.first.group.endsWith(':0')) return 0;
  return tracks.indexWhere((RecitationTrack t) => t.group.endsWith(':$ayah'));
}
