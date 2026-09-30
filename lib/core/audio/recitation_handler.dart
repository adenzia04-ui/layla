import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// One item in the recitation queue: a bundled file or a URL, what the lock
/// screen says about it, and which *group* it belongs to.
///
/// A group is the unit "next" and "previous" move by. For the duas it is the
/// dua; for the Qur'an it is the ayah. A dua read three times is three
/// tracks in one group, and the forward button skips the group, because
/// "forward" means the next supplication to the person holding the phone,
/// not the next repeat of the one they are on.
@immutable
class RecitationTrack {
  const RecitationTrack({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.album,
    this.asset,
    this.url,
    this.pass = 1,
    this.passes = 1,
  }) : assert(asset != null || url != null, 'a track needs a source');

  /// Unique within the queue.
  final String id;

  /// The dua number, or the ayah key such as `2:255`.
  final String group;
  final String title;
  final String subtitle;
  final String album;

  /// A bundled file, `assets/…`.
  final String? asset;

  /// A remote file, fetched once and kept on the device after that.
  final Uri? url;

  /// 1-based repeat within the group.
  final int pass;
  final int passes;

  @override
  bool operator ==(Object other) =>
      other is RecitationTrack &&
      other.id == id &&
      other.group == group &&
      other.asset == asset &&
      other.url == url &&
      other.pass == pass &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(id, group, asset, url, pass, passes);
}

/// What is being recited right now, as the screens see it.
@immutable
class NowPlaying {
  const NowPlaying({
    required this.owner,
    required this.track,
    required this.index,
    required this.playing,
    required this.loading,
  });

  /// Who loaded the queue — `dua:27`, `quran:2` — so a screen can tell its
  /// own recitation from another screen's.
  final String owner;
  final RecitationTrack track;
  final int index;
  final bool playing;
  final bool loading;
}

/// The one recitation player, kept alive by the OS.
///
/// Behind `audio_service`, so the lock screen and the earphones get play,
/// pause, next and previous, and closing the app does not stop a dua or an
/// ayah mid-word. One player for every recitation in the app — the duas,
/// the Qur'an — because iOS shows one "now playing" and it should always be
/// the thing that is actually sounding.
///
/// Deliberately its own player rather than the app-wide plumbing that
/// `just_audio_background` offers: that package allows exactly one
/// `AudioPlayer` in the whole app, and Layla Pro already has three others
/// (the mat scanner's chime, the Mood recitations, the reminder-sound
/// picker).
class RecitationHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  RecitationHandler() {
    _player.playbackEventStream.listen(
      _broadcast,
      onError: (Object e) {
        debugPrint('Layla Pro: recitation player error ($e)');
      },
    );
    _player.sequenceStateStream.listen(_onSequence);
    // The queue ends: back to the start, stopped, so the lock screen shows
    // something that makes sense rather than a spinner on the last item.
    _player.processingStateStream.listen((ProcessingState state) {
      if (state == ProcessingState.completed) {
        unawaited(_player.pause());
        unawaited(_player.seek(Duration.zero, index: 0));
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  List<RecitationTrack> _tracks = const <RecitationTrack>[];
  String _owner = '';
  bool _loop = false;

  final StreamController<NowPlaying?> _now =
      StreamController<NowPlaying?>.broadcast();

  /// What is playing, or null when nothing is loaded.
  Stream<NowPlaying?> get nowPlaying => _now.stream;
  NowPlaying? _last;
  NowPlaying? get current => _last;

  Stream<Duration> get position => _player.positionStream;
  Stream<Duration?> get duration => _player.durationStream;
  bool get isPlaying => _player.playing;

  /// The mark, as a file the lock screen can show. Assets are not files, so
  /// it is written out once into the app's own folder; a failure here only
  /// means the lock screen shows no artwork.
  static Future<Uri?> _art() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final File file = File('${dir.path}/recitation_art.png');
      if (!file.existsSync()) {
        final ByteData data = await rootBundle.load(
          'assets/images/dua_art.png',
        );
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      return file.uri;
    } on Object catch (e) {
      debugPrint('Layla Pro: recitation artwork unavailable ($e)');
      return null;
    }
  }

  /// Loads a queue and starts at [start]. Loading the same queue again with
  /// the same settings just seeks, so tapping another item in a list is
  /// instant.
  ///
  /// [loop] repeats the whole queue when it ends — a surah played on repeat.
  Future<void> load(
    List<RecitationTrack> tracks, {
    required String owner,
    required int start,
    bool loop = false,
  }) async {
    if (tracks.isEmpty || start < 0 || start >= tracks.length) return;

    final bool same =
        owner == _owner && loop == _loop && listEquals(tracks, _tracks);
    if (!same) {
      _tracks = tracks;
      _owner = owner;
      _loop = loop;
      final Uri? art = await _art();
      final List<MediaItem> items = <MediaItem>[
        for (final RecitationTrack t in tracks)
          MediaItem(
            id: t.id,
            title: t.title,
            album: t.album,
            artist: 'Layla Pro',
            displaySubtitle: t.subtitle,
            artUri: art,
          ),
      ];
      final List<AudioSource> sources = <AudioSource>[
        for (int i = 0; i < tracks.length; i++)
          if (tracks[i].asset != null)
            AudioSource.asset(tracks[i].asset!, tag: items[i])
          else
            // ignore: experimental_member_use
            LockCachingAudioSource(tracks[i].url!, tag: items[i]),
      ];
      queue.add(items);
      await _player.setLoopMode(loop ? LoopMode.all : LoopMode.off);
      await _player.setAudioSources(sources, initialIndex: start);
    } else {
      await _player.seek(Duration.zero, index: start);
    }
    await _player.play();
  }

  /// Whether [owner]'s queue is the one loaded.
  bool owns(String owner) => _owner == owner && _tracks.isNotEmpty;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _tracks = const <RecitationTrack>[];
    _owner = '';
    _last = null;
    _now.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Next group, not next repeat.
  @override
  Future<void> skipToNext() async {
    final int? i = _player.currentIndex;
    if (i == null || _tracks.isEmpty) return;
    final String group = _tracks[i].group;
    int next = _tracks.indexWhere((RecitationTrack t) => t.group != group, i);
    if (next < 0) {
      if (!_loop) return;
      next = 0;
    }
    await _player.seek(Duration.zero, index: next);
  }

  /// Back to the start of this group's first repeat; pressed again within
  /// the first two seconds, the previous group.
  @override
  Future<void> skipToPrevious() async {
    final int? i = _player.currentIndex;
    if (i == null || _tracks.isEmpty) return;
    final String group = _tracks[i].group;
    int first = i;
    while (first > 0 && _tracks[first - 1].group == group) {
      first--;
    }
    if (first == i && _player.position < const Duration(seconds: 2)) {
      int prev = first - 1;
      if (prev < 0) return;
      final String prevGroup = _tracks[prev].group;
      while (prev > 0 && _tracks[prev - 1].group == prevGroup) {
        prev--;
      }
      first = prev;
    }
    await _player.seek(Duration.zero, index: first);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  void _onSequence(SequenceState? state) {
    final int? i = state?.currentIndex;
    if (i == null || i < 0 || i >= _tracks.length) return;
    final MediaItem? tag = state?.currentSource?.tag as MediaItem?;
    if (tag != null) mediaItem.add(tag);
    _emit(i);
  }

  void _emit(int i) {
    _last = NowPlaying(
      owner: _owner,
      track: _tracks[i],
      index: i,
      playing: _player.playing,
      loading:
          _player.processingState == ProcessingState.loading ||
          _player.processingState == ProcessingState.buffering,
    );
    _now.add(_last);
  }

  /// Mirrors the player into the OS controls.
  void _broadcast(PlaybackEvent event) {
    final bool playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: const <ProcessingState, AudioProcessingState>{
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
    final int? i = _player.currentIndex;
    if (i != null && i >= 0 && i < _tracks.length) _emit(i);
  }
}
