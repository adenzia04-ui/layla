import 'package:flutter/material.dart';

/// The "Layl" (night) palette — merged from the four reference designs:
/// the deep navy + gold line-art grid, the night-mosque photography, and the
/// per-prayer gradient cards.
abstract final class AppColors {
  // ── Ground ────────────────────────────────────────────────────────────
  static const Color midnight = Color(0xFF060D1B); // scaffold floor
  static const Color navy = Color(0xFF0B1B34); // default surface
  static const Color navyElevated = Color(0xFF12294A); // cards on navy
  static const Color navyLine = Color(0xFF1D3A63); // hairlines, borders

  // ── Accent ────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFD9B26A);
  static const Color goldSoft = Color(0xFFF0D9A8);
  static const Color goldDim = Color(0xFF8A7038);

  // ── Text ──────────────────────────────────────────────────────────────
  static const Color cream = Color(0xFFF6F1E7); // primary on dark
  static const Color mist = Color(0xB3F6F1E7); // 70% — secondary on dark
  static const Color mistFaint = Color(0x66F6F1E7); // 40% — tertiary on dark

  // ── Light surface (bottom sheets, auth cards) ─────────────────────────
  static const Color bone = Color(0xFFFBF8F3);
  static const Color boneMuted = Color(0xFFEFE9DF);
  static const Color ink = Color(0xFF10182A); // primary on light
  static const Color inkMuted = Color(0xFF5C6579); // secondary on light

  // ── Semantic ──────────────────────────────────────────────────────────
  static const Color emerald = Color(0xFF2E9E80); // confirmed / success
  static const Color emeraldDeep = Color(0xFF1B6B56);
  static const Color amber = Color(0xFFE0A23C); // awaiting proof
  static const Color rose = Color(0xFFCF5C6B); // missed / error
  static const Color ember = Color(0xFFF07A3C); // streak flame

  // ── Gradients ─────────────────────────────────────────────────────────
  static const LinearGradient nightSky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B1B34), Color(0xFF060D1B)],
  );

  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldSoft, gold, goldDim],
  );
}

/// Each prayer owns a colour identity, lifted straight from the widget
/// reference (Fajr deep blue → Dhuhr amber → Asr sky → Maghrib violet →
/// Isha navy), with Tahajjud added as indigo-and-gold.
enum PrayerPalette {
  fajr(Color(0xFF16305C), Color(0xFF2B5AA0), Color(0xFFBFD4F2)),
  sunrise(Color(0xFFE8A98A), Color(0xFFF3D3C0), Color(0xFF5A3421)),
  dhuhr(Color(0xFFD9701A), Color(0xFFF2B544), Color(0xFF4A2606)),
  asr(Color(0xFF2F7FC4), Color(0xFF86C5EE), Color(0xFF0C2E4B)),
  maghrib(Color(0xFF6E4EA8), Color(0xFFC6A0E4), Color(0xFF2A1B44)),
  isha(Color(0xFF0C1B38), Color(0xFF1F3C74), Color(0xFFC9D8F5)),
  tahajjud(Color(0xFF101B3D), Color(0xFF2A2060), Color(0xFFF0D9A8));

  const PrayerPalette(this.start, this.end, this.onSurface);

  /// Top-left of the card gradient.
  final Color start;

  /// Bottom-right of the card gradient.
  final Color end;

  /// Text colour that stays legible on this gradient.
  final Color onSurface;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, end],
      );

  /// A dimmed version for inactive list rows.
  LinearGradient get mutedGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(start, AppColors.navy, 0.55)!,
          Color.lerp(end, AppColors.navy, 0.55)!,
        ],
      );
}
