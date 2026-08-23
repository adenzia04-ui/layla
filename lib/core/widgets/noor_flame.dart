import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The streak flame.
///
/// Three overlapping "petals" rather than one silhouette — an outer ember
/// body, a gold middle leaf, and a pale inner curl — which is what gives the
/// reference its depth. A single-colour icon reads flat at any size.
class NoorFlame extends StatelessWidget {
  const NoorFlame({
    super.key,
    this.size = 28,
    this.glow = true,
    this.dimmed = false,
  });

  final double size;

  /// The soft red halo behind it. Worth dropping in dense rows.
  final bool glow;

  /// Greys the flame out for a streak of zero — the shape stays, the fire
  /// doesn't, which reads better than hiding it.
  final bool dimmed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: size,
        width: size * 0.82,
        child: CustomPaint(
          painter: _FlamePainter(glow: glow, dimmed: dimmed),
        ),
      );
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.glow, required this.dimmed});

  final bool glow;
  final bool dimmed;

  /// Outer body — asymmetric, with a tall main tip and a lower secondary
  /// peak on the right. Symmetry is what made the first attempt read as a
  /// generic icon rather than fire.
  Path _body(Size s) {
    double x(double v) => v * s.width;
    double y(double v) => v * s.height;

    return Path()
      ..moveTo(x(0.50), y(1.00))
      ..cubicTo(x(0.05), y(0.95), x(0.01), y(0.62), x(0.21), y(0.40))
      ..cubicTo(x(0.37), y(0.22), x(0.45), y(0.15), x(0.42), y(0.00))
      ..cubicTo(x(0.58), y(0.15), x(0.63), y(0.27), x(0.73), y(0.21))
      ..cubicTo(x(0.81), y(0.36), x(0.99), y(0.58), x(0.95), y(0.78))
      ..cubicTo(x(0.91), y(0.94), x(0.72), y(1.00), x(0.50), y(1.00))
      ..close();
  }

  /// Each inner leaf is an explicit path: up the outer edge to a point, back
  /// down the inner edge to a narrow base.
  ///
  /// Written out longhand rather than generated from offsets — two attempts at
  /// a parametrised crescent produced bars and then hairlines, because the
  /// control points have to move differently for each leaf's angle. Four
  /// literal curves are easier to reason about and to tune.
  Path _leaf(Size s, List<double> pts) {
    double x(double v) => v * s.width;
    double y(double v) => v * s.height;
    return Path()
      ..moveTo(x(pts[0]), y(pts[1]))
      ..cubicTo(x(pts[2]), y(pts[3]), x(pts[4]), y(pts[5]), x(pts[6]), y(pts[7]))
      ..cubicTo(x(pts[8]), y(pts[9]), x(pts[10]), y(pts[11]), x(pts[12]), y(pts[13]))
      ..close();
  }

  // base        outer control pair          tip          inner control pair        base
  static const List<double> _left = <double>[
    0.44, 0.90,  0.20, 0.80,  0.15, 0.55,   0.31, 0.33,   0.37, 0.52,  0.45, 0.68,  0.49, 0.88,
  ];
  static const List<double> _centre = <double>[
    0.45, 0.95,  0.29, 0.72,  0.35, 0.40,   0.47, 0.12,   0.60, 0.40,  0.65, 0.72,  0.57, 0.95,
  ];
  static const List<double> _right = <double>[
    0.55, 0.90,  0.56, 0.68,  0.61, 0.50,   0.71, 0.33,   0.78, 0.56,  0.75, 0.78,  0.64, 0.90,
  ];
  static const List<double> _core = <double>[
    0.47, 0.88,  0.42, 0.72,  0.46, 0.58,   0.52, 0.42,   0.58, 0.58,  0.58, 0.74,  0.55, 0.88,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (dimmed) {
      canvas.drawPath(
        _body(size),
        Paint()..color = AppColors.navyLine.withValues(alpha: 0.9),
      );
      canvas.drawPath(
        _leaf(size, _centre),
        Paint()..color = AppColors.navyElevated,
      );
      return;
    }

    if (glow) {
      final Offset c = Offset(size.width * 0.5, size.height * 0.62);
      canvas.drawCircle(
        c,
        size.width * 0.75,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFE0421C).withValues(alpha: 0.34),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.75)),
      );
    }

    final Rect rect = Offset.zero & size;

    Paint fill(List<Color> colors) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
      ).createShader(rect);

    // Outer body: deep red at the base rising through orange.
    canvas.drawPath(
      _body(size),
      fill(const <Color>[
        Color(0xFFA81C08),
        Color(0xFFEE5A18),
        Color(0xFFF9A22B),
      ]),
    );

    // The two flanking leaves sit behind the centre one.
    canvas.drawPath(
      _leaf(size, _left),
      fill(const <Color>[Color(0xFFE8701C), Color(0xFFFBD98A)]),
    );
    canvas.drawPath(
      _leaf(size, _right),
      fill(const <Color>[Color(0xFFEE7A1E), Color(0xFFFCE3A8)]),
    );

    // Centre leaf — gold, tallest.
    canvas.drawPath(
      _leaf(size, _centre),
      fill(const <Color>[
        Color(0xFFF07A1E),
        Color(0xFFF9C64B),
        Color(0xFFFDEBAE),
      ]),
    );

    // The cream core, which is what makes it look hot rather than orange.
    canvas.drawPath(
      _leaf(size, _core),
      fill(const <Color>[Color(0xFFF6C067), AppColors.cream]),
    );
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.glow != glow || old.dimmed != dimmed;
}
