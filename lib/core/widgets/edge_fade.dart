import 'package:flutter/material.dart';

/// Softens the top and bottom edges of a scrolling child into the ground.
///
/// Content that runs under a bar or a header should thin out before it
/// gets there, not stop at a hard line. The mask fades the child's own
/// pixels, so it works over any background — the night gradient, the
/// mushaf's paper — with nothing painted on top.
class EdgeFade extends StatelessWidget {
  const EdgeFade({
    super.key,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final Widget child;

  /// The height of the fade at each edge, in logical pixels. Zero for none.
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    if (top <= 0 && bottom <= 0) return child;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double h = c.maxHeight.isFinite ? c.maxHeight : 1;
        final double t = (top / h).clamp(0.0, 0.5);
        final double b = (bottom / h).clamp(0.0, 0.5);
        return ShaderMask(
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              if (top > 0) Colors.transparent,
              Colors.white,
              Colors.white,
              if (bottom > 0) Colors.transparent,
            ],
            stops: <double>[if (top > 0) 0, t, 1 - b, if (bottom > 0) 1],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: child,
        );
      },
    );
  }
}
