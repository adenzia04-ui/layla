import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/dua_text.dart';

/// One place in the queue: a dua, and which of its repeats this is.
@immutable
class DuaQueueItem {
  const DuaQueueItem({
    required this.number,
    required this.position,
    required this.pass,
    required this.passes,
  });

  /// The book's number, which is what the recording file is named after.
  final int number;

  /// The dua's place in its section, counting from 1 — the number shown.
  final int position;

  /// 1-based. "2 of 3" is pass 2 of 3 passes.
  final int pass;
  final int passes;

  @override
  bool operator ==(Object other) =>
      other is DuaQueueItem &&
      other.number == number &&
      other.position == position &&
      other.pass == pass &&
      other.passes == passes;

  @override
  int get hashCode => Object.hash(number, position, pass, passes);

  @override
  String toString() => 'Dua $position (#$number, $pass/$passes)';
}

/// The dua being recited right now, as the screens see it.
@immutable
class DuaNowPlaying {
  const DuaNowPlaying({
    required this.item,
    required this.heading,
    required this.playing,
    required this.loading,
  });

  final DuaQueueItem item;

  /// The section's short title, as the library shows it.
  final String heading;
  final bool playing;
  final bool loading;
}

/// The queue a section plays as: every dua in order, each one [repeat]
/// times in a row.
///
/// Repeating is a learning tool — hear it, say it with the reciter, hear it
/// again — so the repeats sit together rather than the whole section looping.
/// A dua the book marks as "×3" is still read once per pass here: the count
/// the person chose is the count they get, and the book's own instruction is
/// printed beside the text where it belongs.
List<DuaQueueItem> buildDuaQueue(List<DuaText> duas, {required int repeat}) {
  final int passes = repeat.clamp(1, 10);
  return <DuaQueueItem>[
    for (int i = 0; i < duas.length; i++)
      if (duas[i].hasArabic)
        for (int pass = 1; pass <= passes; pass++)
          DuaQueueItem(
            number: duas[i].number,
            position: i + 1,
            pass: pass,
            passes: passes,
          ),
  ];
}

/// The recitation, kept alive by the OS.
///
/// One player behind `audio_service`, so the lock screen and the earphones
/// get play, pause, next and previous, and closing the app does not stop the
/// dua mid-word. The recordings are bundled: 267 duas of *Fortress of the
/// Muslim* read aloud, one file each, keyed by the same number the text and
/// the printed page use, so the audio can never drift from the words on the
/// screen.
///
/// Deliberately its own player rather than the app-wide plumbing that
/// `just_audio_background` offers: that package allows exactly one
/// `AudioPlayer` in the whole app, and Layla Pro already has three (the mat
/// scanner's chime, the Mood recitations, the reminder-sound picker).
class DuaAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  DuaAudioHandler() {
    _player.playbackEventStream.listen(
      _broadcast,
      onError: (Object e) {
        debugPrint('Layla Pro: dua player error ($e)');
      },
    );
    _player.sequenceStateStream.listen(_onSequence);
    // The queue ends: back to the start, stopped, so the lock screen shows
    // something that makes sense rather than a spinner on the last dua.
    _player.processingStateStream.listen((ProcessingState state) {
      if (state == ProcessingState.completed) {
        unawaited(_player.pause());
        unawaited(_player.seek(Duration.zero, index: 0));
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();

  List<DuaQueueItem> _items = const <DuaQueueItem>[];
  String _heading = '';

  final StreamController<DuaNowPlaying?> _now =
      StreamController<DuaNowPlaying?>.broadcast();

  /// What is playing, or null when nothing is loaded.
  Stream<DuaNowPlaying?> get nowPlaying => _now.stream;
  DuaNowPlaying? _last;
  DuaNowPlaying? get current => _last;

  Stream<Duration> get position => _player.positionStream;
  Stream<Duration?> get duration => _player.durationStream;

  static String assetFor(int number) => 'assets/duas/audio/$number.m4a';

  /// The mark, as a file the lock screen can show. Assets are not files, so
  /// it is written out once into the app's own folder; a failure here only
  /// means the lock screen shows no artwork.
  static Future<Uri?> _art() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final File file = File('${dir.path}/dua_art.png');
      if (!file.existsSync()) {
        final ByteData data = await rootBundle.load(
          'assets/images/dua_art.png',
        );
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      return file.uri;
    } on Object catch (e) {
      debugPrint('Layla Pro: dua artwork unavailable ($e)');
      return null;
    }
  }

  /// Loads a section and starts at [startNumber], each dua read [repeat]
  /// times. Loading the same section again with the same settings just seeks,
  /// so tapping a different dua in the list is instant.
  Future<void> playSection({
    required List<DuaText> duas,
    required String heading,
    required int startNumber,
    required int repeat,
  }) async {
    final List<DuaQueueItem> items = buildDuaQueue(duas, repeat: repeat);
    final int start = items.indexWhere(
      (DuaQueueItem i) => i.number == startNumber,
    );
    if (start < 0) return;

    final bool same = listEquals(items, _items) && heading == _heading;
    if (!same) {
      _items = items;
      _heading = heading;
      final Uri? art = await _art();
      final List<AudioSource> sources = <AudioSource>[
        for (final DuaQueueItem item in items)
          AudioSource.asset(
            assetFor(item.number),
            tag: MediaItem(
              id: '${item.number}#${item.pass}',
              // "Dua 1 · Evening Adhkar", then the app's name — what the
              // lock screen shows, in that order.
              title: 'Dua ${item.position} · $heading',
              album: heading,
              displaySubtitle: item.passes > 1
                  ? 'Layla Pro · ${item.pass} of ${item.passes}'
                  : 'Layla Pro',
              artist: 'Layla Pro',
              artUri: art,
            ),
          ),
      ];
      queue.add(<MediaItem>[
        for (final AudioSource s in sources)
          (s as IndexedAudioSource).tag as MediaItem,
      ]);
      await _player.setAudioSources(sources, initialIndex: start);
    } else {
      await _player.seek(Duration.zero, index: start);
    }
    await _player.play();
  }

  bool get isPlaying => _player.playing;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _items = const <DuaQueueItem>[];
    _heading = '';
    _last = null;
    _now.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Next *dua*, not next repeat: the lock screen's forward button should
  /// move on to the next supplication, which is what "forward" means to
  /// someone learning them, not replay the one they are on.
  @override
  Future<void> skipToNext() async {
    final int? i = _player.currentIndex;
    if (i == null) return;
    final int number = _items[i].number;
    final int next = _items.indexWhere(
      (DuaQueueItem it) => it.number != number,
      i,
    );
    if (next < 0) return;
    await _player.seek(Duration.zero, index: next);
  }

  /// Back to the start of this dua's first repeat; pressed again within the
  /// first two seconds, the previous dua.
  @override
  Future<void> skipToPrevious() async {
    final int? i = _player.currentIndex;
    if (i == null) return;
    final int number = _items[i].number;
    int first = i;
    while (first > 0 && _items[first - 1].number == number) {
      first--;
    }
    if (first == i && _player.position < const Duration(seconds: 2)) {
      int prev = first - 1;
      if (prev < 0) return;
      final int prevNumber = _items[prev].number;
      while (prev > 0 && _items[prev - 1].number == prevNumber) {
        prev--;
      }
      first = prev;
    }
    await _player.seek(Duration.zero, index: first);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _items.length) return;
    await _player.seek(Duration.zero, index: index);
  }

  void _onSequence(SequenceState? state) {
    final int? i = state?.currentIndex;
    if (i == null || i < 0 || i >= _items.length) return;
    final MediaItem? tag = state?.currentSource?.tag as MediaItem?;
    if (tag != null) mediaItem.add(tag);
    _emit(i);
  }

  void _emit(int i) {
    _last = DuaNowPlaying(
      item: _items[i],
      heading: _heading,
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
    if (i != null && i >= 0 && i < _items.length) _emit(i);
  }
}
