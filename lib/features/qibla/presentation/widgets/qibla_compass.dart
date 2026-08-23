import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/mihrab_arch.dart';

/// The compass face: a rotating gold dial, cardinal marks, and a Kaaba needle
/// that turns emerald the moment the phone is facing the Qibla.
class QiblaCompass extends StatelessWidget {
  const QiblaCompass({
    super.key,
    required this.heading,
    required this.qiblaBearing,
    required this.aligned,
    this.size = 300,
  });

  /// Device heading in degrees; null when there is no magnetometer.
  final double? heading;
  final double qiblaBearing;
  final bool aligned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double dialTurns = ((heading ?? 0) * -1) / 360;
    final double needleTurns = qiblaBearing / 360;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // outer glow when aligned
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            height: size,
            width: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: aligned
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.34),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
          ),
          // the dial turns opposite the phone, so north stays north
          AnimatedRotation(
            turns: dialTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: Size.square(size),
              painter: _DialPainter(aligned: aligned),
            ),
          ),
          // the needle sits at the Qibla bearing, inside the rotating dial
          AnimatedRotation(
            turns: dialTurns + needleTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: SizedBox(
              height: size,
              width: size,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.055),
                  child: _KaabaNeedle(aligned: aligned, size: size * 0.15),
                ),
              ),
            ),
          ),
          // fixed centre hub
          Container(
            height: size * 0.30,
            width: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navy,
              border: Border.all(
                color: aligned ? AppColors.emerald : AppColors.goldDim,
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              height: size * 0.16,
              width: size * 0.12,
              child: MihrabOutline(
                color: aligned ? AppColors.emerald : AppColors.gold,
                strokeWidth: 1.2,
                innerArch: false,
              ),
            ),
          ),
          // fixed pointer at the top of the screen — "you are facing this way"
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 30,
              color: aligned ? AppColors.emerald : AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

class _KaabaNeedle extends StatelessWidget {
  const _KaabaNeedle({required this.aligned, required this.size});

  final bool aligned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = aligned ? AppColors.emerald : AppColors.gold;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: size,
          width: size * 0.82,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            height: size * 0.22,
            width: size * 0.82,
            color: AppColors.midnight.withValues(alpha: 0.55),
          ),
        ),
        Container(
          height: size * 0.5,
          width: 2,
          color: color.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.aligned});

  final bool aligned;

  static const List<String> _cardinals = <String>['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;

    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (aligned ? AppColors.emerald : AppColors.goldDim)
            .withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      c,
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.navyLine,
    );

    // 72 ticks: every 5°, longer every 30°
    for (int i = 0; i < 72; i++) {
      final double angle = i * 5 * math.pi / 180 - math.pi / 2;
      final bool major = i % 6 == 0;
      final double inner = r * (major ? 0.84 : 0.90);
      final double outer = r * 0.965;
      canvas.drawLine(
        c + Offset(math.cos(angle), math.sin(angle)) * inner,
        c + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..strokeWidth = major ? 1.6 : 0.8
          ..strokeCap = StrokeCap.round
          ..color = major
              ? AppColors.cream.withValues(alpha: 0.55)
              : AppColors.cream.withValues(alpha: 0.18),
      );
    }

    for (int i = 0; i < 4; i++) {
      final double angle = i * 90 * math.pi / 180 - math.pi / 2;
      final Offset position =
          c + Offset(math.cos(angle), math.sin(angle)) * (r * 0.68);
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _cardinals[i],
          style: AppType.titleSm.copyWith(
            color: i == 0 ? AppColors.gold : AppColors.mist,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.aligned != aligned;
}
