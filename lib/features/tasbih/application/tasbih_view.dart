import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/prefs_service.dart';

/// How the counter looks. The count is identical in every one — this is only
/// what your thumb is looking at, and people are particular about it.
enum CounterStyle {
  ring('Ring', 'A progress circle', Icons.radio_button_unchecked_rounded),
  gold('Gold beads', 'A misbaha in the app\'s gold', Icons.blur_linear_rounded),
  jade('Jade beads', 'The traditional green', Icons.blur_linear_rounded),
  pearl(
    'Pearl beads',
    'Mother-of-pearl, cool white',
    Icons.blur_linear_rounded,
  ),
  amethyst('Amethyst beads', 'Cool violet stone', Icons.blur_linear_rounded),
  rose('Rose quartz beads', 'Soft pink stone', Icons.blur_linear_rounded),
  signet(
    'Signet beads',
    'Navy glass, each stamped with the mark',
    Icons.blur_linear_rounded,
  ),
  layla('Layla Pro', 'Count on the mark itself', Icons.auto_awesome_rounded);

  const CounterStyle(this.label, this.blurb, this.icon);

  final String label;
  final String blurb;
  final IconData icon;

  /// The ring and the gold misbaha are free; every other face is Premium.
  bool get isPremium => switch (this) {
    CounterStyle.ring || CounterStyle.gold => false,
    CounterStyle.jade ||
    CounterStyle.pearl ||
    CounterStyle.amethyst ||
    CounterStyle.rose ||
    CounterStyle.signet ||
    CounterStyle.layla => true,
  };

  /// Exhaustive rather than `this != ring`, so adding a counter face forces a
  /// decision here instead of silently being treated as a strand.
  bool get isStrand => switch (this) {
    CounterStyle.ring || CounterStyle.layla => false,
    CounterStyle.gold ||
    CounterStyle.jade ||
    CounterStyle.pearl ||
    CounterStyle.amethyst ||
    CounterStyle.rose ||
    CounterStyle.signet => true,
  };

  /// The signet treatment: beads stamped with the mark, strung on a laid navy
  /// rope. One design rather than two independent options — which is why it is
  /// a single flag, so the stamp and the rope cannot drift apart onto
  /// finishes that were never meant to carry either.
  bool get isSignet => this == CounterStyle.signet;

  /// Bead colours, lightest first: highlight, body, shadow.
  ///
  /// The shadow is what sells a bead as a sphere against the navy, so each
  /// finish is a genuine three-step ramp — a pale stone still needs a dark
  /// bottom, or it flattens into a disc.
  List<Color> get beadColours => switch (this) {
    // Vivid, not muted: the old ramp topped out at a dusty mint that read
    // as sea glass. Real jade prayer beads are saturated green.
    CounterStyle.jade => const <Color>[
      Color(0xFF8CF7C4),
      Color(0xFF19C46F),
      Color(0xFF0A5636),
    ],
    CounterStyle.pearl => const <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFD8E2EF),
      Color(0xFF7C8AA3),
    ],
    CounterStyle.amethyst => const <Color>[
      Color(0xFFD9BDFA),
      Color(0xFF8B5CF6),
      Color(0xFF3B1A72),
    ],
    CounterStyle.rose => const <Color>[
      Color(0xFFFFD3DD),
      Color(0xFFE2879C),
      Color(0xFF7A2F45),
    ],
    // Barely lighter than the screen behind it. These beads are read by
    // their gloss and by the gold they carry, not by their colour, so the
    // ramp is wide: a near-white sheen down to almost the background.
    CounterStyle.signet => const <Color>[
      Color(0xFF7C93C4),
      Color(0xFF2E3F63),
      Color(0xFF0E1626),
    ],
    _ => const <Color>[AppColors.goldSoft, AppColors.gold, AppColors.goldDim],
  };

  static CounterStyle byName(String name) => values.firstWhere(
    (CounterStyle s) => s.name == name,
    orElse: () => CounterStyle.ring,
  );
}

final NotifierProvider<TasbihView, CounterStyle> counterStyleProvider =
    NotifierProvider<TasbihView, CounterStyle>(TasbihView.new);

class TasbihView extends Notifier<CounterStyle> {
  @override
  CounterStyle build() =>
      CounterStyle.byName(ref.watch(prefsProvider).tasbihStyle);

  void choose(CounterStyle style) {
    state = style;
    ref.read(prefsProvider).setTasbihStyle(style.name);
  }
}
