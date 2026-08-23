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
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(xl));
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
