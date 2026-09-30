import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Madinah mushaf's ornamental border, in blue.
///
/// The printed page has an arabesque band with rosettes at the corners and
/// a hairline inside it. Drawn rather than bundled: one frame for every
/// page, crisp at any size, with the band in the app's own blue instead
/// of the edition's green.
class MushafFrame extends StatelessWidget {
  const MushafFrame({
    super.key,
    required this.child,
    required this.night,
    this.band = 18,
  });

  final Widget child;

  /// Cream on the night sky rather than ink on paper.
  final bool night;

  /// The width of the ornamental band.
  final double band;

  static const Color paper = Color(0xFFFBF7EE);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FramePainter(night: night, band: band),
      child: Padding(padding: EdgeInsets.all(band + 10), child: child),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.night, required this.band});

  final bool night;
  final double band;

  @override
  void paint(Canvas canvas, Size size) {
    final Color deep = night
        ? const Color(0xFF2E5C9E)
        : const Color(0xFF1F4E8C);
    final Color light = night
        ? const Color(0xFF6E9AD6)
        : const Color(0xFF8DB4E8);
    final Color rose = night
        ? const Color(0xFFD98CB0)
        : const Color(0xFFE39CBD);
    final Color line = night
        ? const Color(0xFF9BB8DE)
        : const Color(0xFF2B5EA6);

    final Rect outer = Offset.zero & size;
    final RRect outerR = RRect.fromRectAndRadius(
      outer,
      const Radius.circular(6),
    );
    final Rect inner = outer.deflate(band);
    final Rect hairline = outer.deflate(band + 5);

    // The band: a deep blue field with a lighter rim on both edges.
    canvas.drawRRect(outerR, Paint()..color = deep);
    canvas.drawRect(
      inner,
      Paint()..color = night ? const Color(0xFF0A1428) : MushafFrame.paper,
    );
    final Paint rim = Paint()
      ..color = light
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(outerR.deflate(2), rim);
    canvas.drawRect(inner.inflate(2), rim);

    // Interlace along each side: alternating lozenges and dots, the way the
    // printed border repeats a small motif.
    final Paint motif = Paint()..color = light;
    final Paint bud = Paint()..color = rose;
    final double step = band * 1.35;
    void along(Offset a, Offset b) {
      final double len = (b - a).distance;
      final int n = (len / step).floor();
      if (n < 2) return;
      final double gap = len / n;
      final Offset dir = (b - a) / len;
      for (int i = 1; i < n; i++) {
        final Offset c = a + dir * (gap * i);
        final double r = band * 0.22;
        if (i.isOdd) {
          final Path lozenge = Path()
            ..moveTo(c.dx, c.dy - r * 1.4)
            ..lineTo(c.dx + r, c.dy)
            ..lineTo(c.dx, c.dy + r * 1.4)
            ..lineTo(c.dx - r, c.dy)
            ..close();
          canvas.drawPath(lozenge, motif);
        } else {
          canvas.drawCircle(c, r * 0.75, bud);
        }
      }
    }

    final double mid = band / 2;
    along(Offset(band, mid), Offset(size.width - band, mid));
    along(
      Offset(band, size.height - mid),
      Offset(size.width - band, size.height - mid),
    );
    along(Offset(mid, band), Offset(mid, size.height - band));
    along(
      Offset(size.width - mid, band),
      Offset(size.width - mid, size.height - band),
    );

    // Corner rosettes: an eight-petal flower on a disc.
    void rosette(Offset c) {
      canvas.drawCircle(c, band * 0.62, Paint()..color = light);
      canvas.drawCircle(c, band * 0.52, Paint()..color = deep);
      for (int i = 0; i < 8; i++) {
        final double angle = i * math.pi / 4;
        final Offset p =
            c + Offset(math.cos(angle), math.sin(angle)) * band * 0.3;
        canvas.drawCircle(p, band * 0.12, bud);
      }
      canvas.drawCircle(c, band * 0.11, motif);
    }

    rosette(Offset(mid, mid));
    rosette(Offset(size.width - mid, mid));
    rosette(Offset(mid, size.height - mid));
    rosette(Offset(size.width - mid, size.height - mid));

    // The hairline the text sits inside.
    canvas.drawRect(
      hairline,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.night != night || old.band != band;
}
