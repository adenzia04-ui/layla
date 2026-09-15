import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google's four-colour "G".
///
/// Drawn rather than bundled as an image. Google's brand guidelines require
/// the mark to keep its colours and proportions, and a `g_mobiledata` glyph —
/// which is what this button used to show — is a thin monochrome letter that
/// meets neither. Painting it keeps the mark correct at every size and text
/// scale without an asset to ship, lose, or render blurry on a 3x screen.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 21});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  /// The brand colours, in the order they run clockwise from the top.
  static const Color _blue = Color(0xFF4285F4);
  static const Color _green = Color(0xFF34A853);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _red = Color(0xFFEA4335);

  /// Degrees, canvas convention: 0 is 3 o'clock and positive runs clockwise.
  static const List<(Color, double, double)> _arcs = <(Color, double, double)>[
    (_red, -160, 105), // over the top, from upper-left to upper-right
    (_blue, -55, 75), // down the right side to the crossbar
    (_green, 25, 95), // round the bottom
    (_yellow, 120, 80), // back up the left, closing the ring
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double stroke = size.width * 0.22;
    final Rect ring = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    ).deflate(stroke / 2);
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (final (Color colour, double from, double sweep) in _arcs) {
      canvas.drawArc(
        ring,
        from * math.pi / 180,
        sweep * math.pi / 180,
        false,
        arc..color = colour,
      );
    }

    // The crossbar, which is what makes it a G rather than an O. It runs from
    // the middle of the ring out to the right edge, in the same blue as the
    // arc it continues.
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.48,
        size.height / 2 - stroke / 2,
        size.width,
        size.height / 2 + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter oldDelegate) => false;
}
