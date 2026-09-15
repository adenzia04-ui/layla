import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Two families, one job each:
/// • **Outfit** — prayer names, screen titles, the name on Home. Geometric
///   and warm; it replaced Playfair, whose high contrast read as severe.
///   This is the serif from the prayer-widget reference; it carries the app's
///   character.
/// • **Inter** — every piece of UI text, with tabular numerals so countdowns
///   don't jitter as the digits change.
abstract final class AppType {
  /// Variable fonts need the `wght` axis set explicitly as well as
  /// `fontWeight` — without the variation the renderer picks the default
  /// instance and every weight looks identical.
  static List<FontVariation> _wght(FontWeight w) => <FontVariation>[
    FontVariation('wght', w.value.toDouble()),
  ];

  static TextStyle _display(double size, {FontWeight w = FontWeight.w600}) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: w,
        fontVariations: _wght(w),
        height: 1.12,
        letterSpacing: -0.4,
      );

  static TextStyle _ui(
    double size, {
    FontWeight w = FontWeight.w500,
    double height = 1.35,
    double spacing = 0,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    fontWeight: w,
    fontVariations: _wght(w),
    height: height,
    letterSpacing: spacing,
  );

  /// Qur'anic text, in the mushaf's own script.
  ///
  /// Amiri Quran, not Inter and not the system fallback. Neither of the app's
  /// Latin faces has any Arabic at all, so this used to land on whatever iOS
  /// substituted, which places the Uthmani marks badly because it was never
  /// drawn for them.
  ///
  /// The generous line height is not decoration either: Uthmani text stacks
  /// marks above and below the baseline, and at a normal height they collide
  /// with the line above.
  static TextStyle quran(double size) =>
      TextStyle(fontFamily: 'AmiriQuran', fontSize: size, height: 2.0);

  /// Arabic that is not Qur'an — the dhikr phrases. Amiri proper, which has
  /// the wider coverage of the two.
  static TextStyle arabic(double size, {double height = 1.8}) =>
      TextStyle(fontFamily: 'Amiri', fontSize: size, height: height);

  // ── Display (Outfit) ────────────────────────────────────────────────
  static TextStyle get displayXl => _display(46, w: FontWeight.w700);
  static TextStyle get displayLg => _display(34, w: FontWeight.w700);
  static TextStyle get displayMd => _display(26);
  static TextStyle get displaySm => _display(20);

  /// The hero clock — "6:35" — tabular so it never shifts width.
  static TextStyle get clock => TextStyle(
    fontFamily: 'Inter',
    fontSize: 54,
    fontWeight: FontWeight.w700,
    fontVariations: _wght(FontWeight.w700),
    height: 1,
    letterSpacing: -2,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Seconds and the meridiem beside the hero clock.
  ///
  /// Tabular, like [clock] itself. Without it Inter's proportional digits make
  /// ":11" narrower than ":40", so the row's width changed every second and
  /// the whole clock slid sideways as it ticked.
  static TextStyle get clockSuffix => _ui(
    20,
    w: FontWeight.w600,
    spacing: 0.4,
  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]);

  /// Countdown and prayer-time numerals.
  static TextStyle get numeral => TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: FontWeight.w600,
    fontVariations: _wght(FontWeight.w600),
    height: 1.2,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  // ── UI (Inter) ────────────────────────────────────────────────────────
  static TextStyle get titleLg => _ui(20, w: FontWeight.w700, height: 1.25);
  static TextStyle get titleMd => _ui(17, w: FontWeight.w600);
  static TextStyle get titleSm => _ui(15, w: FontWeight.w600);
  static TextStyle get body => _ui(15, w: FontWeight.w400, height: 1.5);
  static TextStyle get bodySm => _ui(13, w: FontWeight.w400, height: 1.45);
  static TextStyle get button => _ui(16, w: FontWeight.w600, spacing: 0.1);

  /// Small uppercase eyebrow — "NEXT PRAYER", "TODAY'S PROGRESS".
  static TextStyle get label => _ui(11, w: FontWeight.w600, spacing: 1.4);

  /// Builds the Material text theme for a given foreground colour.
  static TextTheme themeFor(Color onSurface) {
    final TextTheme base = TextTheme(
      displayLarge: displayXl,
      displayMedium: displayLg,
      displaySmall: displayMd,
      headlineMedium: displaySm,
      titleLarge: titleLg,
      titleMedium: titleMd,
      titleSmall: titleSm,
      bodyLarge: body,
      bodyMedium: bodySm,
      labelLarge: button,
      labelSmall: label,
    );
    return base.apply(bodyColor: onSurface, displayColor: onSurface);
  }
}

/// Convenience so widgets can write `context.text.titleMd` instead of
/// reaching for Theme.of every time.
extension TextThemeX on BuildContext {
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// True when this subtree sits on a light sheet rather than the night sky.
  bool get onLightSurface =>
      Theme.of(this).colorScheme.surface.computeLuminance() > 0.5;
}

/// Shared shorthand for the two foreground colours used across the app.
abstract final class Fg {
  static const Color onDark = AppColors.cream;
  static const Color onLight = AppColors.ink;
}
