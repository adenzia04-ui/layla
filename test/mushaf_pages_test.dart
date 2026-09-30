import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/quran/data/mushaf_pages.dart';
import 'package:noor/features/quran/domain/quran_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  final Uint8List page = File('assets/quran/pages/1.png').readAsBytesSync();

  setUp(() => dir = Directory.systemTemp.createTempSync('mushaf_pages'));
  tearDown(() => dir.deleteSync(recursive: true));

  MushafPages android({required Future<Uint8List> Function(Uri) fetch}) =>
      MushafPages.withFolder(bundled: false, folder: dir)..fetcher = fetch;

  test('the pages come from the same files the iPhone bundles', () {
    expect(
      MushafPages.urlFor(7).toString(),
      'https://android.quran.com/data/width_1260/page007.png',
    );
    expect(MushafPages.urlFor(604).toString(), endsWith('/page604.png'));
  });

  test('a bundled build draws from the bundle and never fetches', () async {
    final MushafPages p = MushafPages.bundledForTests();
    expect(p.pageImage(3), isA<AssetImage>());
    expect(p.has(604), isTrue);
    expect(p.onPhone, Quran.pageCount);
    expect(await p.downloadAll(), isTrue);
  });

  test('a page is fetched once, kept, and then read from the phone', () async {
    int calls = 0;
    final MushafPages p = android(
      fetch: (Uri u) async {
        calls++;
        return page;
      },
    );
    expect(p.has(5), isFalse);
    expect(p.pageImage(5), isA<FetchedPage>());
    // Two screens asking at once share one fetch.
    await Future.wait(<Future<Uint8List>>[p.bytes(5), p.bytes(5)]);
    expect(calls, 1);
    expect(p.has(5), isTrue);
    expect(p.pageImage(5), isA<FileImage>());
    await p.bytes(5);
    expect(calls, 1, reason: 'the kept copy is used');
    expect(p.bytesOnPhone, page.length);
  });

  test('a reply that is not a page is refused, not kept', () async {
    final MushafPages p = android(
      fetch: (Uri u) async =>
          Uint8List.fromList('<html>blocked</html>'.codeUnits),
    );
    await expectLater(p.bytes(9), throwsA(anything));
    expect(p.has(9), isFalse);
    expect(File('${dir.path}/9.png').existsSync(), isFalse);
  });

  test(
    'download all fetches every missing page and survives failures',
    () async {
      int calls = 0;
      final MushafPages p = android(
        fetch: (Uri u) async {
          calls++;
          // Page 10 fails every time.
          if (u.path.endsWith('page010.png')) throw const SocketException('x');
          return page;
        },
      );
      await p.bytes(2);
      calls = 0;
      int last = 0;
      final bool ok = await p.downloadAll(
        onProgress: (int d, int _) => last = d,
      );
      expect(ok, isFalse, reason: 'page 10 is still missing');
      expect(p.onPhone, Quran.pageCount - 1);
      expect(last, Quran.pageCount);
      expect(calls, Quran.pageCount - 2 + 3, reason: 'page 10 tried three times');
      await p.removeAll();
      expect(p.onPhone, 0);
    },
  );
}
