/// "Support the creator": a one-off thank-you, on Android.
///
/// Consumable Google Play products — each can be given as often as someone
/// likes, and none of them unlocks anything. The ids must match the in-app
/// products created in Play Console exactly; the amount is shown only until
/// Play answers with the real, local price.
enum SupportTip {
  ten('support_10', 10),
  twenty('support_20', 20),
  fifty('support_50', 50),
  sixty('support_60', 60),
  hundred('support_100', 100);

  const SupportTip(this.id, this.dollars);

  final String id;
  final int dollars;

  static Set<String> get ids => <String>{
    for (final SupportTip t in values) t.id,
  };

  static SupportTip? byId(String id) {
    for (final SupportTip t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}
