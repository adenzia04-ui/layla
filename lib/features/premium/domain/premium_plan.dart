/// The three ways to pay for Layla Pro Premium.
///
/// The ids are the App Store Connect product identifiers; they must match
/// exactly what is created there, and once live they never change.
enum PremiumPlan {
  monthly('layla_pro_monthly', 'Monthly', 'Billed every month', '3.99'),
  yearly('layla_pro_yearly', 'Yearly', 'Two months free', '24.99'),
  lifetime('layla_pro_lifetime', 'Lifetime', 'Pay once, keep it', '59.99');

  const PremiumPlan(this.id, this.label, this.blurb, this.fallbackPrice);

  final String id;
  final String label;
  final String blurb;

  /// Shown only until the store has answered with the real, localised price.
  final String fallbackPrice;

  static const Set<String> ids = <String>{
    'layla_pro_monthly',
    'layla_pro_yearly',
    'layla_pro_lifetime',
  };

  static PremiumPlan? byId(String id) {
    for (final PremiumPlan p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// What Premium unlocks. One list, so the paywall, the profile row and the
/// store description all say the same thing.
const List<({String title, String detail})> kPremiumBenefits =
    <({String title, String detail})>[
      (
        title: 'Prayer-mat scan',
        detail:
            'Confirm each prayer by scanning your mat, so the streak is '
            'proof, not a promise.',
      ),
      (
        title: 'Every tasbih counter',
        detail: 'Signet, pearl, amethyst and rose quartz beads.',
      ),
      (
        title: 'Everything else stays free',
        detail:
            'Prayer times, the shield, streaks, Tahajjud, Mood and the '
            'Names are yours either way.',
      ),
    ];
