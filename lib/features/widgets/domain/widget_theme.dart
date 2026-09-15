import 'dart:ui';

/// The colour sets the widgets can draw in.
///
/// The first two are free; the rest come with Premium. The order here is the
/// order on the Settings screen, and the ids are stored on phones and read by
/// the widget extension (`LaylPalette.named` in ios/NoorWidgets/NoorTheme.swift
/// mirrors every value here, so change both together).
///
/// Each ground is a real colour, not a near-black: the point of choosing a
/// set is that the widget on the home screen visibly changes.
enum WidgetTheme {
  midnight(
    'midnight',
    'Midnight',
    'Navy and gold, the app itself',
    Color(0xFF16305E),
    Color(0xFF081228),
    Color(0xFFE2B96A),
    Color(0xFFF3DDA8),
    Color(0xFFF6F1E7),
  ),
  emerald(
    'emerald',
    'Emerald',
    'Deep green, mint light',
    Color(0xFF0F6B52),
    Color(0xFF052E24),
    Color(0xFF8CF0C4),
    Color(0xFFC8F7E2),
    Color(0xFFEFFAF4),
  ),
  rose(
    'rose',
    'Rose',
    'Wine and blush',
    Color(0xFF7A1F58),
    Color(0xFF3A0C2A),
    Color(0xFFFF9CC6),
    Color(0xFFFFD0E3),
    Color(0xFFFFF0F6),
  ),
  ember(
    'ember',
    'Ember',
    'Burnt orange, warm light',
    Color(0xFF8A3A1E),
    Color(0xFF3D160A),
    Color(0xFFFFB37A),
    Color(0xFFFFD9BC),
    Color(0xFFFFF3EA),
  ),
  violet(
    'violet',
    'Violet',
    'Indigo sky, lavender glow',
    Color(0xFF45309C),
    Color(0xFF1D124C),
    Color(0xFFC9B4FF),
    Color(0xFFE4D8FF),
    Color(0xFFF5F1FF),
  ),
  ocean(
    'ocean',
    'Ocean',
    'Teal deep, glass light',
    Color(0xFF0E5C78),
    Color(0xFF052A3A),
    Color(0xFF7FE3FF),
    Color(0xFFC4F1FF),
    Color(0xFFEEF9FD),
  ),
  sapphire(
    'sapphire',
    'Sapphire',
    'Royal blue, ice accent',
    Color(0xFF1E4FB8),
    Color(0xFF0B1F55),
    Color(0xFFA9C8FF),
    Color(0xFFD6E4FF),
    Color(0xFFF1F5FF),
  ),
  slate(
    'slate',
    'Slate',
    'Graphite and silver',
    Color(0xFF2B2F3A),
    Color(0xFF101218),
    Color(0xFFE3E6EE),
    Color(0xFFF6F7FA),
    Color(0xFFF6F6F8),
  ),
  sand(
    'sand',
    'Sand',
    'Warm light, ink on bone',
    Color(0xFFFBF3E3),
    Color(0xFFEBDDC2),
    Color(0xFF8C5A1E),
    Color(0xFFB88A45),
    Color(0xFF2A1B0A),
  );

  const WidgetTheme(
    this.id,
    this.name,
    this.tagline,
    this.top,
    this.bottom,
    this.accent,
    this.accentSoft,
    this.text,
  );

  /// What the App Group carries. Never change an id — it is stored on phones.
  final String id;
  final String name;
  final String tagline;

  /// Top and bottom of the widget's ground.
  final Color top;
  final Color bottom;

  /// The gold role: labels, rings, the lit prayer.
  final Color accent;
  final Color accentSoft;

  /// The cream role: body text.
  final Color text;

  bool get isLight => text.computeLuminance() < 0.3;

  /// The first two sets are free; every other one is Premium.
  bool get isPremium => index >= 2;

  static WidgetTheme byId(String? id) => values.firstWhere(
    (WidgetTheme t) => t.id == id,
    orElse: () => WidgetTheme.midnight,
  );
}
