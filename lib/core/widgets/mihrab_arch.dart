import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Builds the pointed-arch (mihrab) silhouette that is Noor's signature shape.
///
/// [shoulder] is where the straight jambs stop and the curve begins, as a
/// fraction of the height. Lower values give a taller, more slender arch.
Path buildMihrabPath(Size size, {double shoulder = 0.42, double inset = 0}) {
  final double w = size.width - inset * 2;
  final double h = size.height - inset;
  final double springY = h * shoulder;
  final double cx = inset + w / 2;

  return Path()
    ..moveTo(inset, h)
    ..lineTo(inset, springY)
    // left half sweeping up to the point
    ..cubicTo(
      inset,
      springY * 0.34,
      cx - w * 0.30,
      0,
      cx,
      0,
    )
    // right half mirrored back down
    ..cubicTo(
      cx + w * 0.30,
      0,
      inset + w,
      springY * 0.34,
      inset + w,
      springY,
    )
    ..lineTo(inset + w, h)
    ..close();
}

/// Clips a child (usually a photograph or gradient) to the arch.
class MihrabClipper extends CustomClipper<Path> {
  const MihrabClipper({this.shoulder = 0.42});

  final double shoulder;

  @override
  Path getClip(Size size) => buildMihrabPath(size, shoulder: shoulder);

  @override
  bool shouldReclip(MihrabClipper oldClipper) => oldClipper.shoulder != shoulder;
}

/// A filled arch — the soft glowing dome behind the hero clock on Home and on
/// each prayer card, matching the widget reference.
class MihrabGlow extends StatelessWidget {
  const MihrabGlow({
    super.key,
    required this.color,
    this.shoulder = 0.42,
    this.opacity = 0.30,
  });

  final Color color;
  final double shoulder;
  final double opacity;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _MihrabGlowPainter(
          color: color,
          shoulder: shoulder,
          opacity: opacity,
        ),
        size: Size.infinite,
      );
}

class _MihrabGlowPainter extends CustomPainter {
  _MihrabGlowPainter({
    required this.color,
    required this.shoulder,
    required this.opacity,
  });

  final Color color;
  final double shoulder;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = buildMihrabPath(size, shoulder: shoulder);
    final Paint paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MihrabGlowPainter old) =>
      old.color != color || old.opacity != opacity || old.shoulder != shoulder;
}

/// The gold outlined arch used on the splash screen, where [progress] draws
/// the stroke on from the base upwards.
class MihrabOutline extends StatelessWidget {
  const MihrabOutline({
    super.key,
    this.color = AppColors.gold,
    this.strokeWidth = 1.4,
    this.progress = 1,
    this.shoulder = 0.42,
    this.innerArch = true,
  });

  final Color color;
  final double strokeWidth;

  /// 0 → nothing drawn, 1 → the full outline.
  final double progress;
  final double shoulder;

  /// Draws a second, smaller arch inside — the classic mihrab niche.
  final bool innerArch;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _MihrabOutlinePainter(
          color: color,
          strokeWidth: strokeWidth,
          progress: progress,
          shoulder: shoulder,
          innerArch: innerArch,
        ),
        size: Size.infinite,
      );
}

class _MihrabOutlinePainter extends CustomPainter {
  _MihrabOutlinePainter({
    required this.color,
    required this.strokeWidth,
    required this.progress,
    required this.shoulder,
    required this.innerArch,
  });

  final Color color;
  final double strokeWidth;
  final double progress;
  final double shoulder;
  final bool innerArch;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    _drawPartial(canvas, buildMihrabPath(size, shoulder: shoulder), stroke);

    if (innerArch) {
      final double pad = size.width * 0.16;
      canvas.save();
      canvas.translate(pad, size.height * 0.14);
      _drawPartial(
        canvas,
        buildMihrabPath(
          Size(size.width - pad * 2, size.height * 0.86),
          shoulder: shoulder,
        ),
        stroke..color = color.withValues(alpha: 0.45),
      );
      canvas.restore();
    }
  }

  /// Walks each sub-path's metrics so the outline can be animated on.
  void _drawPartial(Canvas canvas, Path path, Paint paint) {
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MihrabOutlinePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
