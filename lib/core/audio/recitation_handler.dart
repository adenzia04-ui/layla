import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// One item in the recitation queue: where the sound comes from, what the
/// lock screen says about it, and how many times it is read before the
/// next one.
///
/// A track is one dua or one ayah. Repeats are not extra copies in the
/// queue — the player loops the item [passes] times and counts — so a
/// 286-ayah surah at 10× is still a queue of 286, and "next" and
/// "previous" are simply the next and previous track.
@immutable
class RecitationTrack {
  const RecitationTrack({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.album,
    this.asset,
    this.file,
    this.url,
    this.passes = 1,
  }) : assert(
         asset != null || file != null || url != null,
         'a track needs a source',
       );

  /// Unique within the queue.
  final String id;

  /// The dua number, or the ayah key such as `2:255`.
  final String group;
  final String title;
  final String subtitle;
  final String album;

  /// A bundled file, `assets/…`.
  final String? asset;

  /// A file already on the device — a recording fetched earlier.
  final String? file;

  /// The recording on the network, played straight from there when it is
  /// not on the device yet.
  final Uri? url;

  /// How many times this track is read before the next.
  final int passes;

  @override
  bool operator ==(Object other) =>
      other is RecitationTrack &&
      other.id == id &&
      other.group == group &&
      other.asset == asset &&
      other.file == file &&
      other.url == url &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(id, group, asset, file, url, passes);
}

/// What is being recited right now, as the screens see it.
@immutable
class NowPlaying {
  const NowPlaying({
    required this.owner,
    required this.track,
    required this.index,
    required this.pass,
    required this.playing,
    required this.loading,
  });

  /// Who loaded the queue — `dua:27`, `quran:2:alafasy` — so a screen can
  /// tell its own recitation from another screen's.
  final String owner;
  final RecitationTrack track;
  final int index;

  /// 1-based: which reading of [track] this is, of `track.passes`.
  final int pass;
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
/// Network recordings are played straight from their https address, never
/// through just_audio's local proxy: the proxy answers on plain http at
/// 127.0.0.1, which iOS App Transport Security refuses unless the app opens
/// itself to arbitrary loads. That is why streamed ayahs were silent on the
/// phone while bundled duas played. Keeping recordings for offline use is
/// `RecitationCache`'s job, and a cached track arrives here as a [file].
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
    _player.currentIndexStream.listen(_onIndex);
    _player.positionDiscontinuityStream.listen(_onDiscontinuity);
    _player.processingStateStream.listen(_onProcessing);
  }

  final AudioPlayer _player = AudioPlayer();

  List<RecitationTrack> _tracks = const <RecitationTrack>[];
  String _owner = '';
  bool _loopAll = false;

  /// Which reading of the current track is sounding.
  int _pass = 1;
  int? _index;
  LoopMode? _applied;

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
  /// [loop] starts the queue again when it ends — a surah on repeat.
  Future<void> load(
    List<RecitationTrack> tracks, {
    required String owner,
    required int start,
    bool loop = false,
  }) async {
    if (tracks.isEmpty || start < 0 || start >= tracks.length) return;

    final bool same =
        owner == _owner && loop == _loopAll && listEquals(tracks, _tracks);
    if (same) {
      await _player.seek(Duration.zero, index: start);
      await _player.play();
      return;
    }

    _tracks = tracks;
    _owner = owner;
    _loopAll = loop;
    _pass = 1;
    _index = null;
    _applied = null;
    final Uri? art = await _art();
    final List<MediaItem> items = <MediaItem>[
      for (final RecitationTrack t in tracks) _mediaItem(t, 1, art),
    ];
    final List<AudioSource> sources = <AudioSource>[
      for (int i = 0; i < tracks.length; i++)
        if (tracks[i].asset != null)
          AudioSource.asset(tracks[i].asset!, tag: items[i])
        else if (tracks[i].file != null)
          AudioSource.file(tracks[i].file!, tag: items[i])
        else
          AudioSource.uri(tracks[i].url!, tag: items[i]),
    ];
    queue.add(items);
    try {
      await _player.setAudioSources(sources, initialIndex: start);
    } on Object catch (e) {
      debugPrint('Layla Pro: recitation would not load ($e)');
      return;
    }
    _applyLoop();
    await _player.play();
  }

  MediaItem _mediaItem(RecitationTrack t, int pass, Uri? art) => MediaItem(
    id: t.id,
    title: t.title,
    album: t.album,
    artist: 'Layla Pro',
    displaySubtitle: t.passes > 1
        ? '${t.subtitle} · $pass of ${t.passes}'
        : t.subtitle,
    artUri: art,
  );

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
    _index = null;
    _now.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// The next track — the next dua or ayah, whatever repeat this one is on.
  @override
  Future<void> skipToNext() async {
    final int? i = _player.currentIndex;
    if (i == null || _tracks.isEmpty) return;
    int next = i + 1;
    if (next >= _tracks.length) {
      if (!_loopAll) return;
      next = 0;
    }
    await _player.seek(Duration.zero, index: next);
  }

  /// Back to the start of this track's first reading; pressed again within
  /// the first two seconds of it, the previous track.
  @override
  Future<void> skipToPrevious() async {
    final int? i = _player.currentIndex;
    if (i == null || _tracks.isEmpty) return;
    final bool atStart =
        _pass == 1 && _player.position < const Duration(seconds: 2);
    if (!atStart) {
      _pass = 1;
      _applyLoop();
      await _player.seek(Duration.zero, index: i);
      _announce(i);
      _emit(i);
      return;
    }
    if (i == 0) return;
    await _player.seek(Duration.zero, index: i - 1);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  // ── Repeats ────────────────────────────────────────────────────────────

  /// While a track has readings left, the player loops it; on its last
  /// reading the loop is released so the queue moves on — or starts over,
  /// when the whole queue is on repeat.
  void _applyLoop() {
    final int? i = _player.currentIndex;
    if (i == null || i >= _tracks.length) return;
    final LoopMode wanted = _pass < _tracks[i].passes
        ? LoopMode.one
        : _loopAll
        ? LoopMode.all
        : LoopMode.off;
    if (wanted == _applied) return;
    _applied = wanted;
    unawaited(_player.setLoopMode(wanted));
  }

  void _onIndex(int? i) {
    if (i == null || i < 0 || i >= _tracks.length) return;
    if (i == _index) return;
    _index = i;
    _pass = 1;
    _applyLoop();
    _announce(i);
    _emit(i);
  }

  /// The player reached the end of the current track and started it again:
  /// one more reading done.
  void _onDiscontinuity(PositionDiscontinuity d) {
    if (d.reason != PositionDiscontinuityReason.autoAdvance) return;
    final int? i = _player.currentIndex;
    if (i == null ||
        i >= _tracks.length ||
        d.previousEvent.currentIndex != d.event.currentIndex) {
      return;
    }
    if (_pass < _tracks[i].passes) _pass++;
    _applyLoop();
    _announce(i);
    _emit(i);
  }

  void _onProcessing(ProcessingState state) {
    if (state != ProcessingState.completed) return;
    // The queue ends: back to the start. Stopped, so the lock screen shows
    // something that makes sense rather than a spinner on the last item —
    // unless the whole thing is on repeat, in which case it goes round.
    if (_loopAll) {
      unawaited(
        _player.seek(Duration.zero, index: 0).then((_) => _player.play()),
      );
    } else {
      unawaited(_player.pause());
      unawaited(_player.seek(Duration.zero, index: 0));
    }
  }

  /// The lock screen's line for the current reading.
  void _announce(int i) {
    final MediaItem? base = _player.sequence.length > i
        ? _player.sequence[i].tag as MediaItem?
        : null;
    if (base == null) return;
    final RecitationTrack t = _tracks[i];
    mediaItem.add(
      base.copyWith(
        displaySubtitle: t.passes > 1
            ? '${t.subtitle} · $_pass of ${t.passes}'
            : t.subtitle,
      ),
    );
  }

  void _emit(int i) {
    _last = NowPlaying(
      owner: _owner,
      track: _tracks[i],
      index: i,
      pass: _pass,
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
