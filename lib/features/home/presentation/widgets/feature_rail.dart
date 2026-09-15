import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The features, as a single scrolling row.
///
/// Replaces a 3×2 grid of outlined cards. Six bordered boxes stacked under the
/// prayer card competed with it for attention and boxed in artwork that reads
/// better unframed — the flame and the misbaha in particular. A rail also lets
/// features be added later without the dashboard growing taller.
class FeatureRail extends StatelessWidget {
  const FeatureRail({super.key, required this.items});

  final List<FeatureItem> items;

  /// Chip plus the gap plus two lines of label. Fixed so the row does not
  /// change height when a one-line label sits beside a two-line one.
  static const double _height = 118;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (BuildContext context, int i) =>
            _FeatureTile(item: items[i]),
      ),
    );
  }
}

class FeatureItem {
  const FeatureItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = AppColors.gold,
    this.iconWidget,
    this.badge,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Tints the chip. A little variety across the six stops the rail reading as
  /// one undifferentiated block.
  final Color accent;

  /// Replaces [icon] when set — the streak tile uses the painted flame.
  final Widget? iconWidget;

  /// Small count in the corner, e.g. how many are praying Tahajjud now.
  final String? badge;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item});

  final FeatureItem item;

  /// Wide enough for "Tahajjud Stories" over two lines without hyphenating.
  static const double _width = 84;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: item.onTap,
          splashColor: item.accent.withValues(alpha: 0.10),
          highlightColor: item.accent.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Column(
              children: <Widget>[
                _chip(),
                const SizedBox(height: Insets.sm),
                Expanded(
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySm.copyWith(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// No plate behind the icon at all — no fill, no outline.
  ///
  /// The tinted square was the last box left after the cards went, and six of
  /// them in a row read as six buttons rather than as one set of features. The
  /// icons carry their own colour, so they hold up unaided at this size.
  Widget _chip() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        SizedBox(
          // A stable hook for layout tests. They used to locate this by the
          // icon inside it, which broke the moment a tile swapped its glyph
          // for artwork — the test was coupled to the design, not the layout
          // it was actually guarding.
          key: const ValueKey<String>('feature-chip'),
          height: 58,
          width: 58,
          child: Center(
            child:
                item.iconWidget ??
                Icon(item.icon, size: 34, color: item.accent),
          ),
        ),
        if (item.badge != null)
          Positioned(
            top: -4,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: item.accent,
                borderRadius: Radii.chip,
              ),
              child: Text(
                item.badge!,
                style: AppType.label.copyWith(
                  color: AppColors.midnight,
                  fontSize: 9,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
