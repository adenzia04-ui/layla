import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The large tap target: a progress ring with the count in the middle. The
/// whole circle is the button, so counting works without looking.
class TasbihRing extends StatefulWidget {
  const TasbihRing({
    super.key,
    required this.count,
    required this.target,
    required this.progress,
    required this.complete,
    required this.onTap,
    this.size = 264,
  });

  final int count;
  final int target;
  final double progress;
  final bool complete;
  final VoidCallback onTap;
  final double size;

  @override
  State<TasbihRing> createState() => _TasbihRingState();
}

class _TasbihRingState extends State<TasbihRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    lowerBound: 0,
    upperBound: 0.045,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleTap() {
    _pulse.forward().then((_) => _pulse.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.complete ? AppColors.emerald : AppColors.gold;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? child) =>
            Transform.scale(scale: 1 - _pulse.value, child: child),
        child: SizedBox(
          height: widget.size,
          width: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: widget.progress),
                duration: Motion.normal,
                curve: Motion.enter,
                builder: (BuildContext context, double value, Widget? child) =>
                    CustomPaint(
                      size: Size.square(widget.size),
                      painter: _RingPainter(progress: value, accent: accent),
                    ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${widget.count}',
                    style: AppType.clock.copyWith(
                      fontSize: 66,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: Radii.chip,
                      border: Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      'of ${widget.target}',
                      style: AppType.numeral.copyWith(
                        fontSize: 13,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 10;

    // inner disc so the whole circle reads as pressable
    canvas.drawCircle(
      c,
      r - 6,
      Paint()..color = AppColors.navyElevated.withValues(alpha: 0.55),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.navyLine,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: -math.pi / 2,
            endAngle: 3 * math.pi / 2,
            colors: <Color>[accent.withValues(alpha: 0.35), accent],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // tick marks around the outside
    for (int i = 0; i < 60; i++) {
      final double angle = i * 6 * math.pi / 180 - math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(angle), math.sin(angle)) * (r + 10),
        i % 5 == 0 ? 1.6 : 0.8,
        Paint()..color = AppColors.cream.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}
