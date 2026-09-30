import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Recordings fetched from the network, kept on the device.
///
/// An ayah is played straight from its https address the first time and
/// fetched into this cache in the background; every time after that it is
/// played from the file, with no signal needed. Files are named after the
/// address, so a recording is never fetched twice and reciters never mix.
///
/// The same folder holds deliberate downloads — a whole surah in one voice,
/// fetched on request so it can be listened to on a week with no Wi-Fi.
/// Nothing here is ever thrown away on its own; what was downloaded stays
/// until the person removes it.
class RecitationCache {
  RecitationCache._(this._root);

  final Directory _root;

  static RecitationCache? _instance;
  static RecitationCache? get instance => _instance;

  /// Called once at start-up. Never throws: without a cache the app simply
  /// streams every time.
  static Future<void> init() async {
    if (_instance != null) return;
    try {
      final Directory dir = await getApplicationSupportDirectory();
      final Directory root = Directory('${dir.path}/recitations');
      if (!root.existsSync()) root.createSync(recursive: true);
      _instance = RecitationCache._(root);
    } on Object catch (e) {
      debugPrint('Layla Pro: recitation cache unavailable ($e)');
    }
  }

  File _fileFor(Uri url) {
    // https://everyayah.com/data/Alafasy_128kbps/002255.mp3
    //   → Alafasy_128kbps_002255.mp3
    // https://server8.mp3quran.net/lhdan/002.mp3 → lhdan_002.mp3
    final List<String> parts = url.pathSegments
        .where((String s) => s.isNotEmpty && s != 'data')
        .toList();
    final String name = parts.join('_').replaceAll(RegExp(r'[^\w.\-]'), '_');
    return File('${_root.path}/$name');
  }

  /// The local copy of [url], or null when it is not on the device yet.
  String? pathIfCached(Uri url) {
    final File f = _fileFor(url);
    return f.existsSync() && f.lengthSync() > 0 ? f.path : null;
  }

  /// True when every one of [urls] is on the device.
  bool allCached(Iterable<Uri> urls) =>
      urls.every((Uri u) => pathIfCached(u) != null);

  /// Bytes on the device for [urls].
  int sizeOf(Iterable<Uri> urls) {
    int total = 0;
    for (final Uri u in urls) {
      final File f = _fileFor(u);
      if (f.existsSync()) total += f.lengthSync();
    }
    return total;
  }

  /// Deletes the local copies of [urls].
  Future<void> remove(Iterable<Uri> urls) async {
    for (final Uri u in urls) {
      final File f = _fileFor(u);
      if (f.existsSync()) await f.delete();
    }
  }

  final Set<Uri> _inFlight = <Uri>{};
  final List<Uri> _pending = <Uri>[];
  bool _draining = false;

  /// Drops whatever is queued but not yet started. A new surah or a new
  /// voice should not wait behind the old one's downloads.
  void cancelPending() => _pending.clear();

  /// Fetches every one of [urls] that is not already on the device, two at
  /// a time, quietly. Failures are dropped: the next play will stream and
  /// try again.
  void prefetch(Iterable<Uri> urls) {
    for (final Uri u in urls) {
      if (pathIfCached(u) != null) continue;
      if (_inFlight.contains(u) || _pending.contains(u)) continue;
      _pending.add(u);
    }
    if (!_draining) unawaited(_drain());
  }

  Future<void> _drain() async {
    _draining = true;
    try {
      while (_pending.isNotEmpty) {
        final List<Uri> batch = _pending.take(2).toList();
        _pending.removeRange(0, batch.length);
        _inFlight.addAll(batch);
        await Future.wait(batch.map(_fetch));
        _inFlight.removeAll(batch);
      }
    } finally {
      _draining = false;
    }
  }

  /// Fetches all of [urls] and reports progress as files land. Returns true
  /// when every file is on the device afterwards. A download the person
  /// asked for, so it is not quiet: it goes three at a time and retries a
  /// failed file once before giving up on it.
  Future<bool> download(
    List<Uri> urls, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final List<Uri> wanted = urls
        .where((Uri u) => pathIfCached(u) == null)
        .toList();
    int done = urls.length - wanted.length;
    onProgress?.call(done, urls.length);
    for (int i = 0; i < wanted.length; i += 3) {
      if (cancelled?.call() ?? false) return false;
      final List<Uri> batch = wanted.sublist(
        i,
        i + 3 > wanted.length ? wanted.length : i + 3,
      );
      await Future.wait(
        batch.map((Uri u) async {
          if (!await _fetch(u)) await _fetch(u);
          done++;
          onProgress?.call(done, urls.length);
        }),
      );
    }
    return allCached(urls);
  }

  Future<bool> _fetch(Uri url) async {
    final File target = _fileFor(url);
    final File tmp = File('${target.path}.part');
    try {
      final http.Response res = await http
          .get(url)
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return false;
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(target.path);
      return true;
    } on Object catch (e) {
      debugPrint('Layla Pro: could not keep $url ($e)');
      if (tmp.existsSync()) tmp.deleteSync();
      return false;
    }
  }

  /// Bytes on the device, for a settings line.
  Future<int> size() async {
    int total = 0;
    await for (final FileSystemEntity e in _root.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<void> clear() async {
    if (_root.existsSync()) {
      await _root.delete(recursive: true);
      _root.createSync(recursive: true);
    }
  }
}

/// "12.4 MB", for a downloads list.
String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final double mb = bytes / (1024 * 1024);
  return mb >= 100 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}
