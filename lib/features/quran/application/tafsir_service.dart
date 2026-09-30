import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Tafsir Ibn Kathir (abridged, English), one ayah at a time.
///
/// Not bundled — it is many times the size of the Qur'an itself — so it is
/// fetched from quran.com's API the first time an ayah's tafsir is opened
/// and kept on the device after that. Ibn Kathir is the one commentary
/// nearly every school reads and cites; it is what a mosque library hands
/// you first.
class TafsirService {
  const TafsirService();

  static const int _ibnKathir = 169;

  Future<String> ibnKathir(String ayahKey) async {
    final File cache = await _cacheFile(ayahKey);
    if (cache.existsSync()) return cache.readAsStringSync();

    final Uri url = Uri.parse(
      'https://api.quran.com/api/v4/tafsirs/$_ibnKathir/by_ayah/$ayahKey',
    );
    final http.Response res = await http
        .get(
          url,
          headers: const <String, String>{
            'Accept': 'application/json',
            'User-Agent': 'LaylaPro/1.0',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('tafsir ${res.statusCode}', uri: url);
    }
    final Map<String, Object?> body =
        jsonDecode(res.body) as Map<String, Object?>;
    final Map<String, Object?> tafsir = body['tafsir']! as Map<String, Object?>;
    final String text = plainText(tafsir['text'] as String? ?? '');
    if (text.isEmpty) throw const FormatException('empty tafsir');
    await cache.writeAsString(text, flush: true);
    return text;
  }

  Future<File> _cacheFile(String key) async {
    final Directory dir = await getApplicationSupportDirectory();
    final Directory folder = Directory('${dir.path}/tafsir');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return File('${folder.path}/${key.replaceAll(':', '_')}.txt');
  }

  /// The API returns HTML. Paragraph and heading breaks become blank lines,
  /// everything else is stripped, and entities are unescaped.
  @visibleForTesting
  static String plainText(String html) {
    String s = html
        .replaceAll(RegExp(r'</(p|div|h\d|li|blockquote)>'), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }
}

final Provider<TafsirService> tafsirServiceProvider = Provider<TafsirService>(
  (Ref ref) => const TafsirService(),
);

final FutureProviderFamily<String, String> tafsirProvider =
    FutureProvider.family<String, String>(
      (Ref ref, String ayahKey) =>
          ref.watch(tafsirServiceProvider).ibnKathir(ayahKey),
    );
