import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Where every word sits on every printed page.
///
/// The Madinah page images are bundled at 1260 pixels wide, and the Quran
/// Android project publishes the glyph boxes for exactly that rendering —
/// one box per word, per pause mark, per ayah-end mark — so the page can
/// light the word being recited, and a touch on a word can start it. The
/// boxes are in image pixels; a screen scales them to wherever the page
/// is drawn.
@immutable
class Glyph {
  const Glyph({
    required this.surah,
    required this.ayah,
    required this.position,
    required this.line,
    required this.box,
  });

  final int surah;
  final int ayah;

  /// 1-based, counting every token of the ayah as the mushaf sets it —
  /// words and lone pause marks alike — with the ayah-end mark last.
  final int position;
  final int line;
  final Rect box;

  String get ayahKey => '$surah:$ayah';
}

class PageGlyphs {
  const PageGlyphs(this.page, this.glyphs);

  final int page;
  final List<Glyph> glyphs;

  List<Glyph> ofAyah(String key) =>
      glyphs.where((Glyph g) => g.ayahKey == key).toList();

  /// The glyph under [p], in image pixels, or null between words. A line's
  /// glyphs are widened to meet their neighbours, so a touch in the small
  /// gap between two words still lands on one of them.
  Glyph? hit(Offset p) {
    Glyph? best;
    double bestDistance = double.infinity;
    for (final Glyph g in glyphs) {
      if (p.dy < g.box.top - 6 || p.dy > g.box.bottom + 6) continue;
      final double dx = p.dx < g.box.left
          ? g.box.left - p.dx
          : p.dx > g.box.right
          ? p.dx - g.box.right
          : 0;
      if (dx < bestDistance) {
        bestDistance = dx;
        best = g;
      }
    }
    return bestDistance <= 40 ? best : null;
  }
}

class MushafGlyphs {
  const MushafGlyphs._(this.imageSize, this._pages);

  /// The size of the page images the boxes were measured on.
  final Size imageSize;
  final Map<int, PageGlyphs> _pages;

  PageGlyphs? page(int number) => _pages[number];
  int get pageCount => _pages.length;

  static MushafGlyphs parse(String json) {
    final Map<String, Object?> raw = jsonDecode(json) as Map<String, Object?>;
    final Size size = Size(
      (raw['width']! as int).toDouble(),
      (raw['height']! as int).toDouble(),
    );
    final Map<int, PageGlyphs> pages = <int, PageGlyphs>{};
    (raw['pages']! as Map<String, Object?>).forEach((String p, Object? v) {
      final int page = int.parse(p);
      final List<Glyph> glyphs = <Glyph>[];
      (v! as Map<String, Object?>).forEach((String key, Object? list) {
        final List<String> sa = key.split(':');
        final int surah = int.parse(sa[0]);
        final int ayah = int.parse(sa[1]);
        for (final Object? row in list! as List<Object?>) {
          final List<Object?> r = row! as List<Object?>;
          glyphs.add(
            Glyph(
              surah: surah,
              ayah: ayah,
              position: r[0]! as int,
              line: r[1]! as int,
              box: Rect.fromLTRB(
                (r[2]! as int).toDouble(),
                (r[4]! as int).toDouble(),
                (r[3]! as int).toDouble(),
                (r[5]! as int).toDouble(),
              ),
            ),
          );
        }
      });
      pages[page] = PageGlyphs(page, glyphs);
    });
    return MushafGlyphs._(size, pages);
  }

  static Future<MushafGlyphs> load() async {
    final String json = await rootBundle.loadString('assets/quran/glyphs.json');
    return compute(parse, json);
  }
}
