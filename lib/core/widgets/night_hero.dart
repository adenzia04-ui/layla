import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mihrab_arch.dart';

/// The night-mosque hero from the onboarding reference, drawn rather than
/// photographed: a star field, a crescent, and a domed skyline in silhouette.
///
/// Keeping it procedural means no licensing, no download, no asset weight, and
/// it scales cleanly to every screen size.
class NightHero extends StatelessWidget {
  const NightHero({
    super.key,
    this.starOpacity = 1,
    this.skylineOpacity = 1,
    this.moonPhase = 0.28,
  });

  /// Fades the stars in during the splash animation.
  final double starOpacity;
  final double skylineOpacity;

  /// 0 → new moon, 0.5 → half. Only affects the crescent's thickness.
  final double moonPhase;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _NightHeroPainter(
          starOpacity: starOpacity,
          skylineOpacity: skylineOpacity,
          moonPhase: moonPhase,
        ),
      ),
    ),
  );
}

class _NightHeroPainter extends CustomPainter {
  _NightHeroPainter({
    required this.starOpacity,
    required this.skylineOpacity,
    required this.moonPhase,
  });

  final double starOpacity;
  final double skylineOpacity;
  final double moonPhase;

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    if (starOpacity > 0) _stars(canvas, size);
    _moon(canvas, size);
    if (skylineOpacity > 0) _skyline(canvas, size);
  }

  void _sky(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF0A1430),
            Color(0xFF122A4F),
            Color(0xFF0B1B34),
          ],
          stops: <double>[0, 0.55, 1],
        ).createShader(rect),
    );

    // faint horizon glow behind the skyline
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.86),
      size.width * 0.6,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.gold.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.5, size.height * 0.86),
                radius: size.width * 0.6,
              ),
            ),
    );
  }

  /// Deterministic star field — a fixed seed so stars never twitch on rebuild.
  void _stars(Canvas canvas, Size size) {
    final math.Random random = math.Random(7);
    final Paint paint = Paint();
    for (int i = 0; i < 90; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height * 0.72;
      final double r = random.nextDouble() * 1.3 + 0.4;
      final double alpha = (random.nextDouble() * 0.7 + 0.2) * starOpacity;
      paint.color = AppColors.cream.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _moon(Canvas canvas, Size size) {
    final Offset c = Offset(size.width * 0.80, size.height * 0.17);
    final double r = size.width * 0.062;

    canvas.drawCircle(
      c,
      r * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.goldSoft.withValues(alpha: 0.20 * starOpacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.6)),
    );

    // crescent = full disc minus an offset disc
    final Path crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: c.translate(r * (0.5 + moonPhase), -r * 0.16),
          radius: r * 0.96,
        ),
      ),
    );
    canvas.drawPath(
      crescent,
      Paint()..color = AppColors.goldSoft.withValues(alpha: starOpacity),
    );
  }

  /// A mosque skyline: two minarets, one great dome, two side domes.
  void _skyline(Canvas canvas, Size size) {
    final double baseY = size.height;
    final double groundY = size.height * 0.965;
    final Color body = Color.lerp(
      const Color(0xFF050B18),
      const Color(0xFF0B1B34),
      0.25,
    )!.withValues(alpha: skylineOpacity);
    final Paint fill = Paint()..color = body;
    final Paint rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = AppColors.gold.withValues(alpha: 0.30 * skylineOpacity);

    // ground band
    canvas.drawRect(Rect.fromLTRB(0, groundY, size.width, baseY), fill);

    void minaret(double cx, double height, double width) {
      final double top = groundY - height;
      final Rect shaft = Rect.fromLTRB(
        cx - width / 2,
        top + width * 1.5,
        cx + width / 2,
        groundY,
      );
      canvas.drawRect(shaft, fill);
      canvas.drawRect(shaft, rim);

      // balcony
      canvas.drawRect(
        Rect.fromLTRB(
          cx - width * 0.9,
          top + height * 0.44,
          cx + width * 0.9,
          top + height * 0.44 + width * 0.45,
        ),
        fill,
      );

      // cap
      final Path cap = buildMihrabPath(
        Size(width * 1.6, width * 2.2),
      ).shift(Offset(cx - width * 0.8, top - width * 0.7));
      canvas.drawPath(cap, fill);
      canvas.drawPath(cap, rim);
      canvas.drawCircle(Offset(cx, top - width * 0.95), width * 0.16, fill);
    }

    void dome(double cx, double width, double height) {
      final Path path = buildMihrabPath(
        Size(width, height),
        shoulder: 0.30,
      ).shift(Offset(cx - width / 2, groundY - height));
      canvas.drawPath(path, fill);
      canvas.drawPath(path, rim);
      // finial
      canvas.drawLine(
        Offset(cx, groundY - height - 10),
        Offset(cx, groundY - height),
        rim,
      );
      canvas.drawCircle(Offset(cx, groundY - height - 12), 2.6, fill);
    }

    final double w = size.width;
    dome(w * 0.30, w * 0.20, size.height * 0.14);
    dome(w * 0.70, w * 0.20, size.height * 0.14);
    minaret(w * 0.13, size.height * 0.36, w * 0.028);
    minaret(w * 0.88, size.height * 0.40, w * 0.028);
    dome(w * 0.50, w * 0.34, size.height * 0.25);

    // prayer-hall arcade under the great dome
    for (int i = -2; i <= 2; i++) {
      final double cx = w * 0.5 + i * w * 0.072;
      final Path arch = buildMihrabPath(
        Size(w * 0.045, size.height * 0.055),
      ).shift(Offset(cx - w * 0.0225, groundY - size.height * 0.055));
      canvas.drawPath(arch, rim);
    }
  }

  @override
  bool shouldRepaint(_NightHeroPainter old) =>
      old.starOpacity != starOpacity ||
      old.skylineOpacity != skylineOpacity ||
      old.moonPhase != moonPhase;
}
