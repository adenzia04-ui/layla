import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// How many of the ninety-nine are known, as a thin gold ring with the
/// number inside.
class KnownRing extends StatelessWidget {
  const KnownRing({super.key, required this.known, this.size = 56});

  final int known;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(known / 99),
        child: Center(
          child: Text(
            '$known',
            style: AppType.titleSm.copyWith(
              color: AppColors.goldSoft,
              fontSize: size * 0.3,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect ring = rect.deflate(2.5);
    canvas.drawArc(
      ring,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.navyLine,
    );
    if (fraction > 0) {
      canvas.drawArc(
        ring,
        -pi / 2,
        2 * pi * fraction.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = AppColors.gold,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
