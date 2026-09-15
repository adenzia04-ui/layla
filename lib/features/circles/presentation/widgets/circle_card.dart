import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../friends/presentation/widgets/friend_numbers.dart';
import '../../application/circles_controller.dart';
import '../../domain/circle.dart';
import 'circle_bar.dart';
import 'circle_goal_label.dart';

/// One circle on the Friends screen: its name, where it is in its forty
/// days, and the bar everyone in it shares.
class CircleCard extends ConsumerWidget {
  const CircleCard({super.key, required this.circle, required this.onTap});

  final Circle circle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = DateTime.now();
    final List<CircleProgress> progress =
        ref.watch(circleMembersProgressProvider(circle.id)).valueOrNull ??
        const <CircleProgress>[];
    final int day = circleDayOn(circle, now);
    final bool finished = circle.isOver(now);
    final int members = circle.members.length;

    return NightCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(circle.goal.icon, size: 18, color: AppColors.gold),
              const SizedBox(width: Insets.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      circle.name,
                      style: AppType.titleMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${circle.goal.label} · '
                      '${finished ? 'Forty days done' : FriendNumbers.dayOf(day, circle.days)}',
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.mistFaint,
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          CircleBar(fraction: circle.sharedFraction(progress, now)),
          const SizedBox(height: Insets.sm),
          Text(
            '${circleKept(circle, progress)} of ${circlePossible(circle, now)} kept '
            'so far · ${members == 1 ? 'just you' : '$members of you'}',
            style: AppType.bodySm.copyWith(
              color: AppColors.mistFaint,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
