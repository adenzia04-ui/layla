import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The night-sky layer behind a screen's header: crescents and scattered
/// stars, at low opacity so text always wins.
///
/// There used to be a scalloped garland here with four lanterns hanging from
/// it. It was drawn from the top edge down, which meant a wavy line and four
/// vertical threads crossing the title of every screen that used it — read as
/// scratches on the glass rather than decoration, and gave the eye a hard edge
/// to catch on exactly where the heading needed to be legible.
///
/// Points of light have no edge to catch on, so they sit behind text without
/// competing with it.
class OrnamentBackdrop extends StatelessWidget {
  const OrnamentBackdrop({
    super.key,
    this.color = AppColors.goldSoft,
    this.opacity = 0.16,
    this.height,
  });

  final Color color;
  final double opacity;

  /// Constrains the ornament band; defaults to 38% of the available height.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double h =
              height ??
              (constraints.hasBoundedHeight
                  ? constraints.maxHeight * 0.38
                  : 280);
          return SizedBox(
            width: double.infinity,
            height: h,
            child: CustomPaint(
              painter: _OrnamentPainter(
                color: color.withValues(alpha: opacity),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrnamentPainter extends CustomPainter {
  _OrnamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = color;

    _crescent(canvas, Offset(size.width * 0.93, size.height * 0.14), 13, line);
    _crescent(canvas, Offset(size.width * 0.07, size.height * 0.52), 9, line);

    // A scattered field rather than a row: fixed positions, varied sizes, so
    // it reads as sky instead of as a pattern. Hand-placed rather than random
    // because the painter must draw the same thing every frame.
    for (final (double x, double y, double r) in <(double, double, double)>[
      (0.21, 0.16, 7),
      (0.80, 0.42, 6),
      (0.34, 0.62, 5),
      (0.62, 0.12, 8),
      (0.47, 0.34, 4),
      (0.13, 0.30, 5),
      (0.88, 0.68, 4),
      (0.70, 0.74, 6),
      (0.29, 0.86, 4),
      (0.55, 0.58, 3),
    ]) {
      _star(canvas, Offset(size.width * x, size.height * y), r, line);
    }
  }

  void _crescent(Canvas canvas, Offset c, double r, Paint paint) {
    final Path outer = Path()
      ..addArc(
        Rect.fromCircle(center: c, radius: r),
        math.pi * 0.42,
        math.pi * 1.16,
      );
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
  bool shouldRepaint(_OrnamentPainter old) => old.color != color;
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
