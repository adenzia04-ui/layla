import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../../streaks/domain/prayer_day.dart';

/// The day's six moments as a 3×2 grid — label above, time below.
///
/// Replaces the horizontal strip, which put two of the six off-screen and made
/// the day something you had to scrub through. A grid shows the whole day at
/// once, which is the question this section actually answers.
///
/// Sunrise is included because it bounds Fajr, but it is not a prayer: it
/// carries no confirmation state and never takes the active ring.
class PrayerGrid extends StatelessWidget {
  const PrayerGrid({
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

  static const List<PrayerId> _order = <PrayerId>[
    PrayerId.fajr,
    PrayerId.sunrise,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha,
  ];

  @override
  Widget build(BuildContext context) {
    final PrayerSlot? active = schedule.currentAt(now);

    return Column(
      children: <Widget>[
        for (int row = 0; row < 2; row++) ...<Widget>[
          if (row > 0) const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              for (int col = 0; col < 3; col++) ...<Widget>[
                if (col > 0) const SizedBox(width: Insets.sm),
                Expanded(child: _cell(_order[row * 3 + col], active)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _cell(PrayerId id, PrayerSlot? active) {
    final PrayerSlot slot = schedule.slotFor(id);
    return _GridTile(
      id: id,
      // `clock`, not `time`: no meridiem. A prayer's half of the day is
      // never in doubt, and dropping it buys the numerals real size.
      time: Fmt.clock(slot.start, use24h: use24h),
      isActive: id.isObligatory && active?.id == id,
      status: id.isObligatory ? day.recordFor(id).status : null,
      onTap: onTapPrayer == null ? null : () => onTapPrayer!(id),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.id,
    required this.time,
    required this.isActive,
    required this.status,
    this.onTap,
  });

  final PrayerId id;
  final String time;
  final bool isActive;

  /// Null for sunrise, which cannot be confirmed.
  final PrayerStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Deliberately not the per-prayer gradients used elsewhere. Six tinted
    // tiles side by side read as six unrelated buttons; the grid wants to be
    // one object, with colour reserved for saying which prayer is running.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.navyElevated
              : AppColors.navyElevated.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: isActive
                ? AppColors.gold.withValues(alpha: 0.85)
                : AppColors.navyLine.withValues(alpha: 0.55),
            width: isActive ? 1.4 : 1,
          ),
          boxShadow: isActive
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    id.label.toUpperCase(),
                    style: AppType.label.copyWith(
                      color: isActive
                          ? AppColors.goldSoft
                          : AppColors.mist.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    child: Text(
                      time,
                      style: AppType.numeral.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cream,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Confirmation state sits in the corner rather than in the column:
            // the eye should land on the time first, and a tick that shifts the
            // layout when it appears makes the grid twitch as the day goes on.
            if (status != null && status != PrayerStatus.pending)
              Positioned(
                top: 7,
                right: 8,
                child: _StatusPip(status: status!),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPip extends StatelessWidget {
  const _StatusPip({required this.status});

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
          // A cross, not a dash: the user said outright they missed it, and
          // the mark should read as clearly as the tick beside it.
          icon: Icons.cancel_rounded,
          color: AppColors.rose,
        ),
      PrayerStatus.pending => (
          icon: Icons.circle_outlined,
          color: AppColors.mistFaint,
        ),
    };
    return Icon(look.icon, size: 13, color: look.color);
  }
}
