import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recitation_cache.dart';
import '../../../core/services/prefs_service.dart';
import '../domain/quran_data.dart';
import '../domain/reciters.dart';

/// A surah kept on the device in one voice.
@immutable
class SurahDownload {
  const SurahDownload({required this.surah, required this.reciterId});

  final int surah;
  final String reciterId;

  String get key => '$reciterId:$surah';

  static SurahDownload? parse(String key) {
    final int i = key.lastIndexOf(':');
    if (i < 0) return null;
    final int? surah = int.tryParse(key.substring(i + 1));
    if (surah == null || surah < 1 || surah > 114) return null;
    return SurahDownload(surah: surah, reciterId: key.substring(0, i));
  }

  @override
  bool operator ==(Object other) =>
      other is SurahDownload &&
      other.surah == surah &&
      other.reciterId == reciterId;

  @override
  int get hashCode => Object.hash(surah, reciterId);
}

/// A download in flight: how many of the surah's files have landed.
@immutable
class DownloadProgress {
  const DownloadProgress({required this.done, required this.total});

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

/// The surahs on the device, by voice.
///
/// Remembered as a list of keys rather than found by scanning the folder:
/// the folder also holds the sliding-window cache of whatever was last
/// played, and a surah counts as downloaded only when the person asked for
/// all of it. A key whose files have gone missing is dropped the first time
/// it is looked at.
final NotifierProvider<Downloads, Set<String>> downloadsProvider =
    NotifierProvider<Downloads, Set<String>>(Downloads.new);

class Downloads extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(prefsProvider).quranDownloads;

  bool has(SurahDownload d) => state.contains(d.key);

  /// True when every file of [d] is really on the device.
  ///
  /// Read-only, so it is safe to call from a build: a screen that finds a
  /// download gone asks [prune] to forget it afterwards, not mid-build.
  bool verify(SurahDownload d, Quran quran) {
    if (!state.contains(d.key)) return false;
    final RecitationCache? cache = RecitationCache.instance;
    if (cache == null) return false;
    final Reciter r = reciterById(d.reciterId);
    return cache.allCached(r.filesFor(d.surah, quran.surah(d.surah).ayahCount));
  }

  /// Forgets every remembered download whose files are no longer all on
  /// the device — after the OS cleared storage, say.
  void prune(Quran quran) {
    final Set<String> keep = <String>{
      for (final String k in state)
        if (SurahDownload.parse(k) case final SurahDownload d)
          if (verify(d, quran)) k,
    };
    if (keep.length == state.length) return;
    state = keep;
    ref.read(prefsProvider).setQuranDownloads(keep);
  }

  void _remember(SurahDownload d) {
    state = <String>{...state, d.key};
    ref.read(prefsProvider).setQuranDownloads(state);
  }

  void _forget(SurahDownload d) {
    state = state.where((String k) => k != d.key).toSet();
    ref.read(prefsProvider).setQuranDownloads(state);
  }

  Future<void> remove(SurahDownload d, Quran quran) async {
    final RecitationCache? cache = RecitationCache.instance;
    final Reciter r = reciterById(d.reciterId);
    await cache?.remove(r.filesFor(d.surah, quran.surah(d.surah).ayahCount));
    _forget(d);
  }
}

/// Downloads in flight, keyed like [SurahDownload.key].
final NotifierProvider<DownloadQueue, Map<String, DownloadProgress>>
downloadQueueProvider =
    NotifierProvider<DownloadQueue, Map<String, DownloadProgress>>(
      DownloadQueue.new,
    );

class DownloadQueue extends Notifier<Map<String, DownloadProgress>> {
  final Set<String> _cancelled = <String>{};

  @override
  Map<String, DownloadProgress> build() => const <String, DownloadProgress>{};

  bool isRunning(SurahDownload d) => state.containsKey(d.key);

  /// Fetches every file of [d]. Returns true when the whole surah is on the
  /// device afterwards.
  Future<bool> start(SurahDownload d, Quran quran) async {
    final RecitationCache? cache = RecitationCache.instance;
    if (cache == null || state.containsKey(d.key)) return false;
    final Reciter r = reciterById(d.reciterId);
    // The surah's own files, and its Bismillah — shared by every surah in
    // this voice, so it is fetched with each but never counted towards one
    // (removing a surah must not take another's Bismillah with it).
    final Uri? bismillah = quran.surah(d.surah).hasBismillah
        ? r.bismillahFor(d.surah)
        : null;
    final List<Uri> files = <Uri>[
      ...r.filesFor(d.surah, quran.surah(d.surah).ayahCount),
      ?bismillah,
    ];
    _cancelled.remove(d.key);
    _set(d.key, DownloadProgress(done: 0, total: files.length));
    final bool ok = await cache.download(
      files,
      onProgress: (int done, int total) =>
          _set(d.key, DownloadProgress(done: done, total: total)),
      cancelled: () => _cancelled.contains(d.key),
    );
    _clear(d.key);
    if (ok) ref.read(downloadsProvider.notifier)._remember(d);
    return ok;
  }

  void cancel(SurahDownload d) => _cancelled.add(d.key);

  void _set(String key, DownloadProgress p) =>
      state = <String, DownloadProgress>{...state, key: p};

  void _clear(String key) =>
      state = <String, DownloadProgress>{...state}..remove(key);
}
