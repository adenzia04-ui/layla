import 'package:flutter/material.dart';

/// The app's calligraphic mark, decoded at the size it is actually drawn.
///
/// The art is 1705px tall and every place it appears draws it far smaller —
/// the splash by nearly five times, the counter picker's swatch by nearly
/// seventeen. Handing the GPU the full bitmap and asking its texture filter to
/// take it down that far is what flattened the engraving into a smear: that
/// filter samples a handful of texels, so most of the detail it is averaging
/// over is simply never read.
///
/// Decoding to the drawn size puts the reduction on the image codec's own
/// resampler, which is built for exactly this, and costs a fraction of the
/// texture memory besides.
class LaylaMark extends StatelessWidget {
  const LaylaMark({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/layla_mark.png',
      height: height,
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: FilterQuality.high,
    );
  }
}
