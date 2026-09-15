import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../domain/story.dart';

class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    this.onTap,
    this.onLike,
    this.onReport,
    this.maxLines = 5,
  });

  final Story story;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onReport;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navyLine,
                  border: Border.all(
                    color: AppColors.goldDim.withValues(alpha: 0.6),
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  story.isAnonymous
                      ? Icons.person_outline_rounded
                      : story.mood.icon,
                  size: 17,
                  color: AppColors.goldSoft,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(story.displayAuthor, style: AppType.titleSm),
                    Text(
                      '${story.mood.label} · ${Fmt.relative(story.createdAt)}',
                      style: AppType.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReport != null)
                IconButton(
                  onPressed: onReport,
                  iconSize: 18,
                  color: AppColors.mistFaint,
                  tooltip: 'Report this story',
                  icon: const Icon(Icons.flag_outlined),
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            story.body,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.55),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              InkWell(
                onTap: onLike,
                borderRadius: Radii.chip,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        story.likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_outline_rounded,
                        size: 17,
                        color: story.likedByMe
                            ? AppColors.gold
                            : AppColors.mistFaint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${story.likeCount}',
                        style: AppType.bodySm.copyWith(color: AppColors.mist),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (onTap != null)
                Text(
                  'Read',
                  style: AppType.bodySm.copyWith(color: AppColors.goldSoft),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown once at the top of the feed and again in the composer.
class StoriesDisclaimer extends StatelessWidget {
  const StoriesDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.navyElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.goldDim.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.goldSoft,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'These are personal experiences shared by other users. They are '
              'not religious rulings, and nothing here promises a particular '
              'outcome from prayer or dua.',
              style: AppType.bodySm.copyWith(
                color: AppColors.mist,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
