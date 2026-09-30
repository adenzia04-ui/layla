import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/quran_data.dart';

/// Where the 604 printed pages come from.
///
/// On the iPhone they are bundled. On Android they are not: Google Play
/// refuses a download over 200 MB, and the pages alone are 72 MB. There
/// they are fetched from the Quran Android project's server — the very
/// files bundled on the iPhone, byte for byte, so the word boxes fit — as
/// each page is opened, and kept on the phone. "Download all" fetches the
/// rest in one go, for reading with no signal.
class MushafPages {
  /// A stand-in for tests and for a run where [init] never happened: the
  /// pages are read from the bundle, as on the iPhone.
  MushafPages.bundledForTests() : bundled = true, _dir = null;

  static MushafPages? _instance;

  /// Before [init], or when it failed, the bundle is assumed.
  static MushafPages get instance =>
      _instance ?? (_instance = MushafPages.bundledForTests());

  @visibleForTesting
  static set instance(MushafPages p) => _instance = p;

  /// True when this build carries the pages.
  final bool bundled;
  final Directory? _dir;

  static const String _probe = 'assets/quran/pages/1.png';

  /// Called once at start-up. Never throws.
  static Future<void> init() async {
    if (_instance != null) return;
    bool bundled;
    try {
      await rootBundle.load(_probe);
      bundled = true;
    } on Object {
      bundled = false;
    }
    Directory? dir;
    if (!bundled) {
      try {
        final Directory support = await getApplicationSupportDirectory();
        dir = Directory('${support.path}/mushaf_pages');
        if (!dir.existsSync()) dir.createSync(recursive: true);
      } on Object catch (e) {
        debugPrint('Layla Pro: mushaf page folder unavailable ($e)');
      }
    }
    _instance = MushafPages.withFolder(bundled: bundled, folder: dir);
  }

  @visibleForTesting
  MushafPages.withFolder({required this.bundled, Directory? folder})
    : _dir = folder;

  /// The Quran Android project's 1260-pixel page, the source of the
  /// bundled ones.
  static Uri urlFor(int page) => Uri.parse(
    'https://android.quran.com/data/width_1260/'
    'page${page.toString().padLeft(3, '0')}.png',
  );

  File? _file(int page) => _dir == null ? null : File('${_dir.path}/$page.png');

  /// True when [page] can be shown with no signal.
  bool has(int page) {
    if (bundled) return true;
    final File? f = _file(page);
    return f != null && f.existsSync() && f.lengthSync() > 0;
  }

  int get onPhone {
    if (bundled) return Quran.pageCount;
    int n = 0;
    for (int p = 1; p <= Quran.pageCount; p++) {
      if (has(p)) n++;
    }
    return n;
  }

  int get bytesOnPhone {
    final Directory? d = _dir;
    if (bundled || d == null || !d.existsSync()) return 0;
    int total = 0;
    for (final FileSystemEntity e in d.listSync()) {
      if (e is File && e.path.endsWith('.png')) total += e.lengthSync();
    }
    return total;
  }

  /// The image to show for [page].
  ImageProvider pageImage(int page) {
    if (bundled) return AssetImage('assets/quran/pages/$page.png');
    final File? f = _file(page);
    if (f != null && has(page)) return FileImage(f);
    return FetchedPage(this, page);
  }

  final Map<int, Future<Uint8List>> _inFlight = <int, Future<Uint8List>>{};

  /// For tests: how a page is fetched.
  @visibleForTesting
  Future<Uint8List> Function(Uri url) fetcher = _get;

  static Future<Uint8List> _get(Uri url) async {
    final http.Response res = await http
        .get(url, headers: const <String, String>{'User-Agent': 'LaylaPro/1.0'})
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw HttpException('page ${res.statusCode}', uri: url);
    }
    return res.bodyBytes;
  }

  static const List<int> _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  /// The bytes of [page], from the phone or fetched and kept. One fetch per
  /// page however many ask at once; a reply that is not a PNG is refused
  /// rather than kept.
  Future<Uint8List> bytes(int page) {
    final File? f = _file(page);
    if (f != null && has(page)) return f.readAsBytes();
    final Future<Uint8List>? running = _inFlight[page];
    if (running != null) return running;
    final Future<Uint8List> fetch = _fetch(page, f);
    _inFlight[page] = fetch;
    // Block bodies on purpose: remove() returns the finished fetch, and
    // returning it from these handlers would raise its error a second time.
    fetch.then<void>(
      (_) {
        _inFlight.remove(page);
      },
      onError: (Object _) {
        _inFlight.remove(page);
      },
    );
    return fetch;
  }

  Future<Uint8List> _fetch(int page, File? f) async {
    Object? last;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
      try {
        final Uint8List data = await fetcher(urlFor(page));
        if (data.length < 8 || !listEquals(data.sublist(0, 8), _pngSignature)) {
          throw FormatException('page $page is not a PNG');
        }
        if (f != null) {
          final File part = File('${f.path}.part');
          await part.writeAsBytes(data, flush: true);
          await part.rename(f.path);
        }
        return data;
      } on Object catch (e) {
        last = e;
      }
    }
    throw last ?? StateError('page $page');
  }

  /// Fetches the pages around [page] in the background, so the next swipe
  /// is instant.
  void warmAround(int page, {int first = 1, int last = Quran.pageCount}) {
    if (bundled) return;
    for (final int p in <int>[page + 1, page - 1, page + 2]) {
      if (p >= first && p <= last && !has(p)) {
        unawaited(bytes(p).then((_) {}, onError: (Object _) {}));
      }
    }
  }

  /// Every page not yet on the phone, a few at a time. True when all 604
  /// are here afterwards.
  Future<bool> downloadAll({
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    if (bundled) return true;
    final List<int> missing = <int>[
      for (int p = 1; p <= Quran.pageCount; p++)
        if (!has(p)) p,
    ];
    int done = Quran.pageCount - missing.length;
    onProgress?.call(done, Quran.pageCount);
    int next = 0;
    Future<void> worker() async {
      while (next < missing.length) {
        if (cancelled?.call() ?? false) return;
        final int p = missing[next++];
        try {
          await bytes(p);
        } on Object {
          // Counted as missing below; the rest carry on.
        }
        done++;
        onProgress?.call(done, Quran.pageCount);
      }
    }

    await Future.wait(<Future<void>>[for (int i = 0; i < 6; i++) worker()]);
    return onPhone == Quran.pageCount;
  }

  /// Lets the downloaded pages go. They come back as they are read.
  Future<void> removeAll() async {
    final Directory? d = _dir;
    if (bundled || d == null || !d.existsSync()) return;
    for (final FileSystemEntity e in d.listSync()) {
      if (e is File) await e.delete();
    }
    PaintingBinding.instance.imageCache.clear();
  }
}

/// A page not on the phone yet: fetched, kept, then drawn.
@immutable
class FetchedPage extends ImageProvider<FetchedPage> {
  const FetchedPage(this.pages, this.page);

  final MushafPages pages;
  final int page;

  @override
  Future<FetchedPage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FetchedPage>(this);

  @override
  ImageStreamCompleter loadImage(
    FetchedPage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: _load(decode),
    scale: 1,
    debugLabel: 'mushaf page $page',
  );

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final Uint8List data = await pages.bytes(page);
    return decode(await ui.ImmutableBuffer.fromUint8List(data));
  }

  @override
  bool operator ==(Object other) => other is FetchedPage && other.page == page;

  @override
  int get hashCode => Object.hash(FetchedPage, page);
}
