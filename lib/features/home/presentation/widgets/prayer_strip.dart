import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../../streaks/domain/prayer_day.dart';

/// The horizontal row of all prayer times with the active one in a pill —
/// taken directly from the widget reference and extended with a confirmation
/// tick, so one glance answers both "what time?" and "did I confirm it?".
class PrayerStrip extends StatelessWidget {
  const PrayerStrip({
    super.key,
    required this.schedule,
    required this.now,
    required this.day,
    this.use24h = false,
    this.onTapPrayer,
  });

  final PrayerSchedule schedule;
  final DateTime now;
  final PrayerDay day;
  final bool use24h;
  final ValueChanged<PrayerId>? onTapPrayer;

  @override
  Widget build(BuildContext context) {
    final PrayerSlot? active = schedule.currentAt(now);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          for (final PrayerSlot slot in schedule.obligatory)
            Padding(
              padding: const EdgeInsets.only(right: Insets.sm),
              child: _StripItem(
                slot: slot,
                isActive: active?.id == slot.id,
                status: day.recordFor(slot.id).status,
                use24h: use24h,
                onTap: onTapPrayer == null ? null : () => onTapPrayer!(slot.id),
              ),
            ),
          _TahajjudStripItem(
            window: schedule.tahajjud,
            prayed: day.tahajjudPrayed,
            isActive: schedule.tahajjud.isActiveAt(now),
            use24h: use24h,
            onTap: onTapPrayer == null
                ? null
                : () => onTapPrayer!(PrayerId.tahajjud),
          ),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    required this.slot,
    required this.isActive,
    required this.status,
    required this.use24h,
    this.onTap,
  });

  final PrayerSlot slot;
  final bool isActive;
  final PrayerStatus status;
  final bool use24h;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PrayerPalette palette = slot.id.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(
          vertical: Insets.md,
          horizontal: Insets.sm,
        ),
        decoration: BoxDecoration(
          gradient: isActive ? palette.gradient : palette.mutedGradient,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: isActive
                ? AppColors.gold.withValues(alpha: 0.8)
                : AppColors.navyLine.withValues(alpha: 0.6),
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              slot.id.icon,
              size: 18,
              color: isActive ? palette.onSurface : AppColors.mistFaint,
            ),
            const SizedBox(height: 6),
            Text(
              slot.id.label,
              style: AppType.titleSm.copyWith(
                color: isActive ? palette.onSurface : AppColors.mist,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              Fmt.time(slot.start, use24h: use24h),
              style: AppType.numeral.copyWith(
                fontSize: 13,
                color: (isActive ? palette.onSurface : AppColors.mist)
                    .withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            _StatusDot(status: status),
          ],
        ),
      ),
    );
  }
}

class _TahajjudStripItem extends StatelessWidget {
  const _TahajjudStripItem({
    required this.window,
    required this.prayed,
    required this.isActive,
    required this.use24h,
    this.onTap,
  });

  final TahajjudWindow window;
  final bool prayed;
  final bool isActive;
  final bool use24h;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const PrayerPalette palette = PrayerPalette.tahajjud;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        width: 86,
        padding: const EdgeInsets.symmetric(
          vertical: Insets.md,
          horizontal: Insets.sm,
        ),
        decoration: BoxDecoration(
          gradient: isActive ? palette.gradient : palette.mutedGradient,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: isActive ? AppColors.gold : AppColors.goldDim,
            width: isActive ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: <Widget>[
            const Icon(
              Icons.bedtime_rounded,
              size: 18,
              color: AppColors.goldSoft,
            ),
            const SizedBox(height: 6),
            Text(
              'Tahajjud',
              style: AppType.titleSm.copyWith(color: AppColors.goldSoft),
            ),
            const SizedBox(height: 2),
            Text(
              Fmt.time(window.start, use24h: use24h),
              style: AppType.numeral.copyWith(
                fontSize: 13,
                color: AppColors.goldSoft.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Icon(
              prayed ? Icons.check_circle : Icons.circle_outlined,
              size: 13,
              color: prayed ? AppColors.emerald : AppColors.mistFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final PrayerStatus status;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, Color color}) look = switch (status) {
      PrayerStatus.completed => (
        icon: Icons.check_circle,
        color: AppColors.emerald,
      ),
      PrayerStatus.awaitingProof => (
        icon: Icons.photo_camera_back_outlined,
        color: AppColors.amber,
      ),
      PrayerStatus.missed => (
        icon: Icons.remove_circle_outline,
        color: AppColors.rose,
      ),
      // Covered by the prayer pause. A neutral dash rather than the rose
      // cross above it: this prayer was never owed, so it must not read as
      // one that was skipped.
      PrayerStatus.excused => (
        icon: Icons.remove_rounded,
        color: AppColors.mistFaint,
      ),
      PrayerStatus.pending => (
        icon: Icons.circle_outlined,
        color: AppColors.mistFaint,
      ),
    };
    return Icon(look.icon, size: 13, color: look.color);
  }
}
