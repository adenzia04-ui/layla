import 'package:flutter/material.dart';

import '../../../../core/widgets/noor_flame.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../../streaks/domain/prayer_day.dart';

/// "Today's Progress — Fajr ✓ Dhuhr ✓ Asr ✓ Maghrib ○ Isha ○ · 7 days 🔥"
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({
    super.key,
    required this.day,
    required this.currentStreak,
    this.onTap,
  });

  final PrayerDay day;
  final int currentStreak;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                "TODAY'S PROGRESS",
                style: AppType.label.copyWith(color: AppColors.gold),
              ),
              const Spacer(),
              Text(
                '${day.completedCount} of ${PrayerId.obligatory.length} confirmed',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              for (final PrayerId id in PrayerId.obligatory)
                Expanded(
                  child: _ProgressPip(
                    label: id.label,
                    status: day.recordFor(id).status,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          ClipRRect(
            borderRadius: Radii.chip,
            child: LinearProgressIndicator(
              minHeight: 5,
              value: day.completedCount / PrayerId.obligatory.length,
              backgroundColor: AppColors.navyLine,
              color: day.isComplete ? AppColors.emerald : AppColors.gold,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              const NoorFlame(size: 20, glow: false),
              const SizedBox(width: 6),
              Text(
                'Current streak',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const Spacer(),
              Text(
                currentStreak == 1 ? '1 day' : '$currentStreak days',
                style: AppType.titleMd.copyWith(color: AppColors.cream),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.mistFaint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressPip extends StatelessWidget {
  const _ProgressPip({required this.label, required this.status});

  final String label;
  final PrayerStatus status;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color}) look = switch (status) {
      PrayerStatus.completed => (
          icon: Icons.check_rounded,
          color: AppColors.emerald,
        ),
      PrayerStatus.awaitingProof => (
          icon: Icons.photo_camera_outlined,
          color: AppColors.amber,
        ),
      PrayerStatus.missed => (
          icon: Icons.close_rounded,
          color: AppColors.rose,
        ),
      PrayerStatus.pending => (
          icon: Icons.circle_outlined,
          color: AppColors.mistFaint,
        ),
    };

    return Column(
      children: <Widget>[
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: look.color.withValues(alpha: 0.14),
            border: Border.all(color: look.color.withValues(alpha: 0.5)),
          ),
          child: Icon(look.icon, size: 17, color: look.color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppType.bodySm.copyWith(
            fontSize: 11,
            color: status == PrayerStatus.pending
                ? AppColors.mistFaint
                : AppColors.mist,
          ),
        ),
      ],
    );
  }
}
