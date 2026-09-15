import 'package:flutter/widgets.dart';

/// Layout tokens. Every gap, radius and duration in Noor comes from here so the
/// app keeps one rhythm across all 23 screens.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  /// Horizontal page padding — the single most repeated value in the app.
  static const double page = 20;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: page);
  static const EdgeInsets card = EdgeInsets.all(lg);
}

abstract final class Radii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
}

abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration splash = Duration(milliseconds: 1800);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasis = Curves.easeOutBack;
}

/// How much of their normal size the vertical gaps on a non-scrolling screen
/// should take, given the room actually available.
///
/// Tasbih and Qibla are the only two screens in Layla Pro that do not scroll — a
/// bead strand and a compass, both meant to sit still under your thumb. That
/// is a deliberate choice, but it removes the escape hatch every other screen
/// has, so when the window is too short something must yield. The Expanded
/// regions absorb what they can; past that these gaps are the only slack left
/// between a tidy layout and a clipped button, and a clipped button is silent
/// in a release build — Flutter paints the overflow stripes only in debug.
///
/// Divided by the text scale because Dynamic Type, not screen size, is what
/// actually runs these screens out of room. Measured: every phone at 1.0x had
/// space to spare, while at 1.3x an SE overran Tasbih by 81px and Qibla by 45,
/// and a 13 mini overran Tasbih by 20. The constants are calibrated to those
/// numbers and held there by responsive_layout_test.dart — retune them by
/// running that, not by eye.
double fitGap(BuildContext context, BoxConstraints constraints) {
  final double textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
  return ((constraints.maxHeight / textScale - 500) / 170).clamp(0.15, 1.0);
}
