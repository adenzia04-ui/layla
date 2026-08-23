import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The gold line-art layer from the navy reference design: a scalloped garland
/// across the top, hanging lanterns, crescents and stars.
///
/// Purely decorative and non-interactive — it sits behind content at low
/// opacity so text always wins.
class OrnamentBackdrop extends StatelessWidget {
  const OrnamentBackdrop({
    super.key,
    this.color = AppColors.goldSoft,
    this.opacity = 0.16,
    this.lanterns = true,
    this.height,
  });

  final Color color;
  final double opacity;
  final bool lanterns;

  /// Constrains the ornament band; defaults to 38% of the available height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double h = height ??
              (constraints.hasBoundedHeight
                  ? constraints.maxHeight * 0.38
                  : 280);
          return SizedBox(
            width: double.infinity,
            height: h,
            child: CustomPaint(
              painter: _OrnamentPainter(
                color: color.withValues(alpha: opacity),
                lanterns: lanterns,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter({required this.color, required this.lanterns});

  final Color color;
  final bool lanterns;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = color;

    _garland(canvas, size, line);

    if (lanterns) {
      _lantern(canvas, size, line, x: 0.12, drop: 0.30, scale: 0.9);
      _lantern(canvas, size, line, x: 0.87, drop: 0.22, scale: 1.0);
      _lantern(canvas, size, line, x: 0.72, drop: 0.46, scale: 0.66);
      _lantern(canvas, size, line, x: 0.26, drop: 0.52, scale: 0.6);
    }

    _crescent(canvas, Offset(size.width * 0.93, size.height * 0.14), 13, line);
    _crescent(canvas, Offset(size.width * 0.07, size.height * 0.52), 9, line);

    for (final Offset star in <Offset>[
      Offset(size.width * 0.21, size.height * 0.16),
      Offset(size.width * 0.80, size.height * 0.42),
      Offset(size.width * 0.34, size.height * 0.62),
      Offset(size.width * 0.62, size.height * 0.12),
    ]) {
      _star(canvas, star, 7, line);
    }
  }

  /// The scalloped multifoil arch that spans the top of the screen.
  void _garland(Canvas canvas, Size size, Paint paint) {
    final double w = size.width;
    final double baseY = size.height * 0.30;
    final double peakY = size.height * 0.10;

    final Path path = Path()..moveTo(-w * 0.05, baseY);
    // three lobes rising to a central point, then mirrored down
    path.cubicTo(w * 0.14, baseY, w * 0.18, peakY + 22, w * 0.30, peakY + 18);
    path.cubicTo(w * 0.40, peakY + 14, w * 0.44, peakY, w * 0.50, peakY);
    path.cubicTo(w * 0.56, peakY, w * 0.60, peakY + 14, w * 0.70, peakY + 18);
    path.cubicTo(w * 0.82, peakY + 22, w * 0.86, baseY, w * 1.05, baseY);
    canvas.drawPath(path, paint);

    // an echo line just below, the way the reference doubles its arch
    canvas.save();
    canvas.translate(0, 9);
    canvas.drawPath(path, paint..color = paint.color.withValues(alpha: 0.55));
    canvas.restore();
    paint.color = color;

    // suspension threads
    for (final double x in <double>[0.12, 0.26, 0.72, 0.87]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * x, size.height * 0.20), paint);
    }
  }

  void _lantern(
    Canvas canvas,
    Size size,
    Paint paint, {
    required double x,
    required double drop,
    required double scale,
  }) {
    final double cx = size.width * x;
    final double top = size.height * drop;
    final double w = 26 * scale;
    final double h = 42 * scale;

    // top finial
    canvas.drawLine(Offset(cx, top - 8 * scale), Offset(cx, top), paint);
    canvas.drawCircle(Offset(cx, top - 10 * scale), 2.4 * scale, paint);

    // body: a lantern is two mirrored arcs pinched at the waist
    final Path body = Path()
      ..moveTo(cx - w * 0.30, top)
      ..lineTo(cx + w * 0.30, top)
      ..cubicTo(cx + w * 0.62, top + h * 0.20, cx + w * 0.52, top + h * 0.72,
          cx + w * 0.26, top + h,)
      ..lineTo(cx - w * 0.26, top + h)
      ..cubicTo(cx - w * 0.52, top + h * 0.72, cx - w * 0.62, top + h * 0.20,
          cx - w * 0.30, top,)
      ..close();
    canvas.drawPath(body, paint);

    // lattice
    canvas.drawLine(
      Offset(cx - w * 0.42, top + h * 0.30),
      Offset(cx + w * 0.42, top + h * 0.30),
      paint,
    );
    canvas.drawLine(
      Offset(cx - w * 0.40, top + h * 0.66),
      Offset(cx + w * 0.40, top + h * 0.66),
      paint,
    );
    final Path diamond = Path()
      ..moveTo(cx, top + h * 0.34)
      ..lineTo(cx + w * 0.24, top + h * 0.50)
      ..lineTo(cx, top + h * 0.64)
      ..lineTo(cx - w * 0.24, top + h * 0.50)
      ..close();
    canvas.drawPath(diamond, paint);

    // bottom finial
    canvas.drawLine(
      Offset(cx, top + h),
      Offset(cx, top + h + 7 * scale),
      paint,
    );
    canvas.drawCircle(Offset(cx, top + h + 9 * scale), 2 * scale, paint);
  }

  void _crescent(Canvas canvas, Offset c, double r, Paint paint) {
    final Path outer = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), math.pi * 0.42,
          math.pi * 1.16,);
    final Path inner = Path()
      ..addArc(
        Rect.fromCircle(center: c.translate(r * 0.34, 0), radius: r * 0.92),
        math.pi * 0.52,
        math.pi * 0.96,
      );
    canvas.drawPath(outer, paint);
    canvas.drawPath(inner, paint);
  }

  /// Four-point sparkle with concave sides.
  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final Path p = Path()..moveTo(c.dx, c.dy - r);
    p.quadraticBezierTo(c.dx + r * 0.16, c.dy - r * 0.16, c.dx + r, c.dy);
    p.quadraticBezierTo(c.dx + r * 0.16, c.dy + r * 0.16, c.dx, c.dy + r);
    p.quadraticBezierTo(c.dx - r * 0.16, c.dy + r * 0.16, c.dx - r, c.dy);
    p.quadraticBezierTo(c.dx - r * 0.16, c.dy - r * 0.16, c.dx, c.dy - r);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_OrnamentPainter old) =>
      old.color != color || old.lanterns != lanterns;
}

/// Eight-pointed star (khatim) used as the app mark and as an accent glyph.
class KhatimMark extends StatelessWidget {
  const KhatimMark({
    super.key,
    this.size = 48,
    this.color = AppColors.gold,
    this.filled = false,
  });

  final double size;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _KhatimPainter(color: color, filled: filled),
      );
}

class _KhatimPainter extends CustomPainter {
  _KhatimPainter({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;
    final Paint paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeJoin = StrokeJoin.round;

    // two overlaid squares, rotated 45° apart — the classic Rub el Hizb
    for (final double turn in <double>[0, math.pi / 4]) {
      final Path square = Path();
      for (int i = 0; i < 4; i++) {
        final double a = turn + i * math.pi / 2 + math.pi / 4;
        final Offset p = c + Offset(math.cos(a), math.sin(a)) * r * 0.98;
        i == 0 ? square.moveTo(p.dx, p.dy) : square.lineTo(p.dx, p.dy);
      }
      square.close();
      canvas.drawPath(square, paint);
    }
    canvas.drawCircle(c, r * 0.16, paint);
  }

  @override
  bool shouldRepaint(_KhatimPainter old) =>
      old.color != color || old.filled != filled;
}
