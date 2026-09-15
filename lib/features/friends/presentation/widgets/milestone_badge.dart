import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/friend.dart';

/// A milestone as a small gold seal: "100 days", "First Tahajjud".
///
/// One widget for both cards, so a friend's badge and your own are the same
/// shape — this is a mark of something reached, not a rank, and it is drawn
/// the same whoever reached it.
class MilestoneBadge extends StatelessWidget {
  const MilestoneBadge({super.key, required this.milestone});

  final MilestoneKey milestone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs + 1,
      ),
      decoration: BoxDecoration(
        borderRadius: Radii.chip,
        color: AppColors.gold.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: AppColors.gold,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              milestone.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySm.copyWith(
                color: AppColors.goldSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
