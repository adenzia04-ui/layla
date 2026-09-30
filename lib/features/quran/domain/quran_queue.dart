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

/// The tracks for [surah], one per ayah, in [reciter]'s voice.
///
/// In [PlayMode.ayahByAyah] every ayah is read [repeat] times (held to 1–10)
/// before the next; in [PlayMode.surah] once. The basmalah is not
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
        );
      }(),
  ];
}

/// Where [ayah] sits in a queue built by [surahTracks], or -1.
int trackIndexOf(List<RecitationTrack> tracks, int ayah) =>
    tracks.indexWhere((RecitationTrack t) => t.group.endsWith(':$ayah'));
