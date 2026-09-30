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
    //   → Alafasy_128kbps/002255.mp3
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

  final Set<Uri> _inFlight = <Uri>{};
  final List<Uri> _pending = <Uri>[];
  bool _draining = false;

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

  Future<void> _fetch(Uri url) async {
    final File target = _fileFor(url);
    final File tmp = File('${target.path}.part');
    try {
      final http.Response res = await http
          .get(url)
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return;
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(target.path);
    } on Object catch (e) {
      debugPrint('Layla Pro: could not keep $url ($e)');
      if (tmp.existsSync()) tmp.deleteSync();
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
