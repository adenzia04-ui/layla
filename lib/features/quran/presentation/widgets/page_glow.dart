import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/mushaf_glyphs.dart';

/// The light on a printed page: the ayah being recited in a soft wash, and
/// the word being spoken in a warmer, brighter one that glides from word
/// to word as the voice moves.
///
/// Boxes come in image pixels; [fitted] is where the image is drawn, so
/// they scale onto it. Nothing is drawn when nothing is playing here.
class PageGlow extends StatelessWidget {
  const PageGlow({
    super.key,
    required this.ayahGlyphs,
    required this.wordPosition,
    required this.imageSize,
    required this.fitted,
    required this.night,
  });

  /// The glyphs of the ayah sounding, on this page. Empty for none.
  final List<Glyph> ayahGlyphs;

  /// The glyph position of the word being spoken, or 0.
  final int wordPosition;
  final Size imageSize;
  final Rect fitted;
  final bool night;

  Rect _scaled(Rect r) {
    final double sx = fitted.width / imageSize.width;
    final double sy = fitted.height / imageSize.height;
    return Rect.fromLTRB(
      fitted.left + r.left * sx,
      fitted.top + r.top * sy,
      fitted.left + r.right * sx,
      fitted.top + r.bottom * sy,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ayahGlyphs.isEmpty) return const SizedBox.shrink();
    // One band per line the ayah runs across.
    final Map<int, Rect> lines = <int, Rect>{};
    for (final Glyph g in ayahGlyphs) {
      final Rect r = _scaled(g.box);
      lines[g.line] = lines[g.line]?.expandToInclude(r) ?? r;
    }
    Rect? word;
    for (final Glyph g in ayahGlyphs) {
      if (g.position == wordPosition) word = _scaled(g.box);
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _AyahWash(lines.values.toList(), night)),
          _WordLight(rect: word, night: night),
        ],
      ),
    );
  }
}

class _AyahWash extends CustomPainter {
  const _AyahWash(this.bands, this.night);

  final List<Rect> bands;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = AppColors.gold.withValues(alpha: night ? 0.16 : 0.15);
    for (final Rect b in bands) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(b.inflate(3), const Radius.circular(6)),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_AyahWash old) =>
      old.night != night || !listEqualsRect(old.bands, bands);

  static bool listEqualsRect(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The light on one word, easing from where it was to where it is.
class _WordLight extends StatelessWidget {
  const _WordLight({required this.rect, required this.night});

  final Rect? rect;
  final bool night;

  @override
  Widget build(BuildContext context) {
    if (rect == null) return const SizedBox.shrink();
    return TweenAnimationBuilder<Rect?>(
      tween: RectTween(end: rect),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Rect? r, Widget? _) {
        if (r == null) return const SizedBox.shrink();
        return CustomPaint(painter: _WordPainter(r, night));
      },
    );
  }
}

class _WordPainter extends CustomPainter {
  const _WordPainter(this.rect, this.night);

  final Rect rect;
  final bool night;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect r = RRect.fromRectAndRadius(
      rect.inflate(2),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      r.inflate(3),
      Paint()
        ..color = AppColors.gold.withValues(alpha: night ? 0.35 : 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      r,
      Paint()..color = AppColors.gold.withValues(alpha: night ? 0.42 : 0.38),
    );
  }

  @override
  bool shouldRepaint(_WordPainter old) =>
      old.rect != rect || old.night != night;
}
