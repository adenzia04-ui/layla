import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/layla_mark.dart';

/// Counting on Layla Pro's own mark.
///
/// The calligraphy is the target: it lifts under the thumb and settles back,
/// with the round's progress drawn as an arc around it. No number competing for
/// attention in the middle — the count sits underneath, where it can be read
/// without being stared at.
class TasbihMark extends StatelessWidget {
  const TasbihMark({
    required this.count,
    required this.target,
    required this.progress,
    required this.onTap,
    super.key,
    this.size = 260,
  });

  /// The square the mark and its ring are drawn in.
  final double size;

  final int count;
  final int target;
  final double progress;
  final VoidCallback onTap;

  /// The art is now cropped to the calligraphy itself, so this is the mark's
  /// own height rather than a square with margins baked into it.
  static const double _markHeight = 152;

  /// Up quickly, back down slowly.
  ///
  /// Returns 0 at rest, 1 at the top of the lift. The velocity is zero at the
  /// peak and zero again at the end, so it settles instead of stopping. The
  /// old motion was an `elasticOut` scale, which overshoots and wobbles — at
  /// this size that read as a twitch rather than something being lifted.
  static double _lift(double t) {
    const double peak = 0.32;
    if (t <= peak) return Curves.easeOutCubic.transform(t / peak);
    return 1 - Curves.easeInOutCubic.transform((t - peak) / (1 - peak));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: size,
            width: 260,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: progress, end: progress),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, double p, _) => CustomPaint(
                    size: Size.square(size),
                    painter: _ArcPainter(progress: p),
                  ),
                ),
                // Keyed on the count so the lift replays on every tap rather
                // than only the first. Linear here on purpose: the shaping is
                // in [_lift], which has to come back down, and a Curve cannot
                // — `Curve.transform` returns t verbatim at both endpoints.
                TweenAnimationBuilder<double>(
                  key: ValueKey<int>(count),
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 560),
                  builder: (BuildContext context, double t, _) {
                    final double lift = _lift(t);
                    return Transform.translate(
                      offset: Offset(0, -16 * lift),
                      child: Transform.scale(
                        scale: 1 + 0.06 * lift,
                        child: _Mark(
                          lift: lift,
                          sweep: t,
                          height: _markHeight * size / 260,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '$count',
                style: AppType.clock.copyWith(
                  fontSize: 34,
                  color: AppColors.cream,
                ),
              ),
              Text(
                ' / $target',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The mark itself: its own glow behind it, and a band of light drawn across
/// the gold on every tap.
class _Mark extends StatelessWidget {
  const _Mark({required this.lift, required this.sweep, required this.height});

  /// The glyph's height, scaled with the dial.
  final double height;

  /// 0 at rest, 1 at the top of the lift.
  final double lift;

  /// The raw 0..1 of the tap, which the sheen rides across the glyph.
  final double sweep;

  /// A band of light crossing the glyph corner to corner.
  ///
  /// Slid by moving the gradient's own alignment rather than its stops: stops
  /// have to stay inside 0..1 and non-decreasing, which means clamping them
  /// and watching the band collapse at both ends of the travel. The alignment
  /// is under no such constraint, and TileMode.clamp holds the transparent
  /// ends steady once the band has left the box.
  Shader _sheen(Rect box) {
    final double p = -1.6 + 3.2 * sweep;
    return LinearGradient(
      begin: Alignment(p - 0.6, p - 0.6),
      end: Alignment(p + 0.6, p + 0.6),
      colors: const <Color>[
        Color(0x00FFFFFF),
        Color(0x59FFFFFF),
        Color(0x00FFFFFF),
      ],
    ).createShader(box);
  }

  @override
  Widget build(BuildContext context) {
    final Widget art = LaylaMark(height: height);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        // Glow: the calligraphy's own silhouette, flooded gold and blurred, so
        // the light comes off the strokes instead of out of a disc behind
        // them. It brightens as the mark rises.
        Opacity(
          opacity: 0.28 + 0.42 * lift,
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 13, sigmaY: 13),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                AppColors.gold,
                BlendMode.srcATop,
              ),
              child: art,
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: _sheen,
          child: art,
        ),
      ],
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2 - 10;
    final Rect box = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppColors.navyLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (progress <= 0) return;

    canvas.drawArc(
      box,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..shader = const SweepGradient(
          colors: <Color>[
            AppColors.goldDim,
            AppColors.gold,
            AppColors.goldSoft,
          ],
        ).createShader(box)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}
