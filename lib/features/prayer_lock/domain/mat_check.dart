import 'package:flutter/foundation.dart';

/// One label Vision returned for a photo.
@immutable
class VisionLabel {
  const VisionLabel(this.label, this.confidence);

  final String label;
  final double confidence;
}

/// What the check decided, and why — the screen shows the reason, so it must
/// be something a person can act on.
enum MatVerdict {
  /// Looks like a mat, or at least like fabric on a floor.
  looksRight,

  /// Confidently something else — a face, the sky, a screen.
  looksWrong,

  /// Vision could not say. Treated as a pass; see [MatCheck.decide].
  unsure,
}

/// Decides whether a Step 2 photo plausibly shows a prayer mat.
///
/// Be clear about what this is. Vision's taxonomy has 1303 classes and none of
/// them is "rug", "carpet" or "prayer mat" — and ML Kit's 400 do not have one
/// either. There is no free prayer-mat classifier. So this cannot recognise a
/// prayer mat, and nothing here pretends to.
///
/// What it can do is reject a photo that is obviously not one: a selfie, the
/// ceiling, the sky, a television. That turns Step 2 from "any photo at all"
/// into "point the camera at the floor", which is the friction the step exists
/// to create. It will still accept a bath towel.
abstract final class MatCheck {
  /// Fabric, floors and the things a mat is made of.
  static const Set<String> _consistent = <String>{
    'textile',
    'material',
    'pattern',
    'wool',
    'cotton',
    'linen',
    'furniture',
    '室内', // Vision emits some identifiers untranslated
    'room',
    'floor',
    'flooring',
    'tile',
    'blanket',
    'bedding',
    'quilt',
    'towel',
    'mat',
    'carpet',
    'rug',
  };

  /// Things a prayer mat is definitively not. A photo dominated by any of
  /// these is a photo of something else.
  static const Set<String> _contradicts = <String>{
    'people',
    'person',
    'face',
    'selfie',
    'portrait',
    'sky',
    'cloud',
    'sunset',
    'tree',
    'plant',
    'flower',
    'animal',
    'dog',
    'cat',
    'bird',
    'food',
    'meal',
    'fruit',
    'vegetable',
    'beverage',
    'screenshot',
    'text_document',
    'document',
    'monitor',
    'television',
    'computer',
    'car',
    'vehicle',
    'street',
    'building',
    'water',
  };

  /// A contradicting label this confident means the photo is of that thing.
  static const double _contradictAt = 0.45;

  /// A supporting label this confident is enough to accept.
  static const double _consistentAt = 0.12;

  /// The trained classifier's own two labels.
  static const String _modelYes = 'mat';
  static const String _modelNo = 'not_mat';

  /// How sure the trained model must be before it overrules nothing at all.
  static const double _modelAt = 0.60;

  /// The zero-shot margin: how much more the photo looks like a prayer mat
  /// than like a carpet or a floor. Positive means mat.
  static const String _margin = 'clip_mat_margin';

  /// Below this, the photo is rejected.
  ///
  /// Measured on 53 prayer mats and 22 carpets. The two groups barely overlap
  /// — carpets ran from -0.131 to +0.002, mats from -0.026 to +0.136 with a
  /// median of +0.053.
  ///
  /// -0.027 was the most accurate cut on that data and is deliberately not
  /// used. A threshold tuned on the set it was measured against always looks
  /// better than it will in the wild, and the two mistakes are not equal:
  /// letting a carpet through costs nothing, while rejecting a real mat tells
  /// someone who has just prayed that the app does not believe them. -0.045
  /// still accepted all 53 mats and gave up only two carpet rejections to buy
  /// headroom for mats nobody has photographed yet.
  static const double _matAt = -0.045;

  /// The band where the on-device check is not trustworthy on its own.
  ///
  /// Measured on 53 prayer mats and 22 carpets. Outside this band every one of
  /// the 64 photos was judged correctly on device; inside it the two groups
  /// interleave and the margin stops meaning anything. Only these go to
  /// Claude — about 15% — which is the difference between a few pounds a month
  /// and a few pence, and keeps 85% of photos on the phone.
  static const double _askBelow = 0.01;
  static const double _askAbove = -0.06;

  /// The bar one frame of a live scan has to clear.
  ///
  /// Far higher than [_matAt], and the reason is that a scanner is not a
  /// photograph. [_matAt] is calibrated for a picture somebody has
  /// deliberately taken of their mat, where turning it down means telling a
  /// person who has just prayed that the app does not believe them — so it is
  /// generous on purpose and lets a carpet through rather than risk that.
  ///
  /// A scanner has sixty chances, not one. A frame it turns down costs half a
  /// second and the next frame tries again, so leniency buys nothing and costs
  /// everything: the margin scores how much more a picture looks like a prayer
  /// mat than like a carpet, which is a question with no meaningful answer for
  /// a laptop, a bag or a doorway. Those land near zero — and near zero is
  /// comfortably above -0.045, which is why the scanner appeared to accept
  /// whatever it was pointed at.
  ///
  /// Every one of the 22 measured carpets scored at or below +0.002 and the 53
  /// mats had a median of +0.053, so +0.02 sits inside the gap between them.
  /// A mat that cannot clear it on any of sixty frames falls through to the
  /// manual capture, which is what that fallback is for.
  static const double _scanAt = 0.02;

  /// The trained classifier's bar for a live frame, likewise raised.
  static const double _scanModelAt = 0.85;

  /// The verdict for one frame of a live scan.
  ///
  /// Deliberately a separate decision from [decide] rather than a parameter on
  /// it. The two are answering different questions — "may this prayer be
  /// confirmed" and "is this worth stopping the scan for" — and the thresholds
  /// behind them were arrived at for opposite reasons. Folding them together
  /// would mean one number quietly serving both, and the first time somebody
  /// tuned it for one they would break the other.
  static MatVerdict decideFrame(List<VisionLabel> labels) {
    if (labels.isEmpty) return MatVerdict.unsure;

    // A confident "this is a face" or "this is a television" settles it before
    // the margin is consulted at all. [decide] cannot do this — the margin
    // returns from it immediately — which is how a screen or a person could
    // score near zero and pass.
    for (final VisionLabel l in labels) {
      if (l.confidence >= _contradictAt &&
          _matches(l.label.toLowerCase(), _contradicts)) {
        return MatVerdict.looksWrong;
      }
    }

    final double? margin = marginOf(labels);
    if (margin != null) {
      return margin >= _scanAt ? MatVerdict.looksRight : MatVerdict.looksWrong;
    }

    final Iterable<VisionLabel> fromModel = labels.where(
      (VisionLabel l) => l.label == _modelYes || l.label == _modelNo,
    );
    if (fromModel.isNotEmpty) {
      final VisionLabel best = fromModel.reduce(
        (VisionLabel a, VisionLabel b) => a.confidence >= b.confidence ? a : b,
      );
      if (best.confidence < _scanModelAt) return MatVerdict.unsure;
      return best.label == _modelYes
          ? MatVerdict.looksRight
          : MatVerdict.looksWrong;
    }

    // Generic labels and nothing else. 'floor' and 'textile' are true of an
    // entire room, so accepting on them is how a scanner ends up firing at a
    // doorway; never fire on them. `MatVision.canScan` keeps the scanner shut
    // on such a build anyway, and this is the second lock on that door.
    return MatVerdict.unsure;
  }

  static bool needsSecondOpinion(double? margin) =>
      margin != null && margin >= _askAbove && margin <= _askBelow;

  /// The margin from a label list, or null when the encoder is not bundled.
  static double? marginOf(List<VisionLabel> labels) {
    for (final VisionLabel l in labels) {
      if (l.label == _margin) return l.confidence;
    }
    return null;
  }

  static MatVerdict decide(List<VisionLabel> labels) {
    if (labels.isEmpty) return MatVerdict.unsure;

    // The zero-shot check answers first when the encoder is bundled.
    for (final VisionLabel l in labels) {
      if (l.label == _margin) {
        return l.confidence >= _matAt
            ? MatVerdict.looksRight
            : MatVerdict.looksWrong;
      }
    }

    // When the trained classifier is bundled it answers on its own terms, and
    // its labels must never reach the generic vocabulary below.
    //
    // That is not tidiness. `_matches` splits identifiers on underscores, so
    // 'not_mat' yields ['not', 'mat'] — and 'mat' is in the accept list. The
    // model saying "definitely not a prayer mat" would have been read as a
    // pass.
    final Iterable<VisionLabel> fromModel = labels.where(
      (VisionLabel l) => l.label == _modelYes || l.label == _modelNo,
    );
    if (fromModel.isNotEmpty) {
      final VisionLabel best = fromModel.reduce(
        (VisionLabel a, VisionLabel b) => a.confidence >= b.confidence ? a : b,
      );
      if (best.confidence < _modelAt) return MatVerdict.unsure;
      return best.label == _modelYes
          ? MatVerdict.looksRight
          : MatVerdict.looksWrong;
    }

    for (final VisionLabel l in labels) {
      final String id = l.label.toLowerCase();
      if (l.confidence >= _contradictAt && _matches(id, _contradicts)) {
        return MatVerdict.looksWrong;
      }
    }
    for (final VisionLabel l in labels) {
      final String id = l.label.toLowerCase();
      if (l.confidence >= _consistentAt && _matches(id, _consistent)) {
        return MatVerdict.looksRight;
      }
    }
    return MatVerdict.unsure;
  }

  /// Whole-word match on Vision's underscore-separated identifiers.
  ///
  /// Substring matching looked tempting and is a trap: 'rug' is inside
  /// 'arugula' and 'rugby', 'mat' is inside 'matches' and 'matzo'. Checking
  /// that way would have let a plate of salad confirm a prayer.
  static bool _matches(String identifier, Set<String> vocabulary) {
    if (vocabulary.contains(identifier)) return true;
    for (final String part in identifier.split('_')) {
      if (vocabulary.contains(part)) return true;
    }
    return false;
  }
}
