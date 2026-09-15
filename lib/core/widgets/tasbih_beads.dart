import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A misbaha — a loop of prayer beads narrowing to a tassel at the top.
///
/// Beads are laid along a teardrop path using `PathMetric`, so changing the
/// loop's shape redistributes them automatically instead of needing every
/// circle repositioned by hand.
class TasbihBeads extends StatelessWidget {
  const TasbihBeads({
    super.key,
    this.size = 24,
    this.color = AppColors.emerald,
    this.beads = 17,
  });

  final double size;
  final Color color;

  /// Bead count around the loop. Real tasbihs run 33 or 99, but at icon
  /// sizes those render as sub-pixel dots that grey into a faint ring — this
  /// reads as beads, which matters more than being literal.
  final int beads;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    width: size * 0.78,
    child: CustomPaint(
      painter: _BeadsPainter(color: color, beads: beads),
    ),
  );
}

class _BeadsPainter extends CustomPainter {
  _BeadsPainter({required this.color, required this.beads});

  final Color color;
  final int beads;

  /// The loop: a teardrop, wide at the base, converging to a point up top.
  Path _loop(Size s) {
    double x(double v) => v * s.width;
    double y(double v) => v * s.height;

    return Path()
      ..moveTo(x(0.50), y(0.22))
      ..cubicTo(x(0.16), y(0.38), x(0.04), y(0.66), x(0.22), y(0.86))
      ..cubicTo(x(0.36), y(1.00), x(0.64), y(1.00), x(0.78), y(0.86))
      ..cubicTo(x(0.96), y(0.66), x(0.84), y(0.38), x(0.50), y(0.22))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    final Path loop = _loop(size);
    final double radius = size.width * 0.075;

    for (final metric in loop.computeMetrics()) {
      final double step = metric.length / beads;
      for (int i = 0; i < beads; i++) {
        final point = metric.getTangentForOffset(step * i);
        if (point == null) continue;
        canvas.drawCircle(point.position, radius, fill);
      }
    }

    // The imam bead where the loop closes, then the tassel above it.
    final Offset apex = Offset(size.width * 0.50, size.height * 0.22);
    canvas.drawCircle(apex, radius * 1.5, fill);

    canvas.drawLine(
      apex.translate(0, -radius),
      Offset(size.width * 0.52, size.height * 0.10),
      Paint()
        ..color = color
        ..strokeWidth = size.width * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // A small leaf finial, as in the reference.
    final Path leaf = Path()
      ..moveTo(size.width * 0.52, size.height * 0.11)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.08,
        size.width * 0.40,
        size.height * -0.01,
        size.width * 0.56,
        size.height * 0.005,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.02,
        size.width * 0.62,
        size.height * 0.09,
        size.width * 0.52,
        size.height * 0.11,
      )
      ..close();
    canvas.drawPath(leaf, fill);
  }

  @override
  bool shouldRepaint(_BeadsPainter old) =>
      old.color != color || old.beads != beads;
}
