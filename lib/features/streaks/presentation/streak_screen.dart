import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/app_user.dart';
import '../../prayer_times/domain/prayer.dart';
import '../application/streak_controller.dart';
import '../domain/prayer_day.dart';
import 'widgets/streak_calendar.dart';

class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserStats stats = ref.watch(userStatsProvider);
    final AsyncValue<StreakHistory> history = ref.watch(streakHistoryProvider);
    final PrayerDay today = ref.watch(todayPrayerDayProvider).value ??
        PrayerDay.empty(Fmt.dayId(DateTime.now()));

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          Text('Prayer Streak', style: AppType.displayLg),
          const SizedBox(height: 4),
          Text(
            'Only prayers confirmed with both steps count here.',
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          _StreakHeadline(stats: stats),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: "Today's progress"),
          _TodayRows(day: today),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Last five weeks'),
          history.when(
            loading: () => const SizedBox(
              height: 200,
              child: LoadingView(),
            ),
            error: (Object error, StackTrace stack) => const ErrorView(
              message: 'Your history could not be loaded.',
            ),
            data: (StreakHistory h) => Column(
              children: <Widget>[
                StreakCalendar(history: h),
                const SizedBox(height: Insets.xl),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _StatTile(
                        label: 'Perfect days',
                        value: '${h.perfectDays}',
                        icon: Icons.verified_rounded,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: _StatTile(
                        label: 'Prayers confirmed',
                        value: '${h.totalConfirmed}',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: _StatTile(
                        label: 'Tahajjud nights',
                        value: '${h.tahajjudNights}',
                        icon: Icons.bedtime_outlined,
                        color: AppColors.goldSoft,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          NightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('How the streak works', style: AppType.titleMd),
                const SizedBox(height: Insets.sm),
                Text(
                  'A day counts once all five prayers are confirmed, and a '
                  'prayer is confirmed only after both steps: pressing "I Have '
                  'Prayed" and uploading a photo of your prayer mat. Missing '
                  'either step leaves the prayer unconfirmed and ends the '
                  'streak at the end of that day.',
                  style: AppType.bodySm
                      .copyWith(color: AppColors.mist, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakHeadline extends StatelessWidget {
  const _StreakHeadline({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF2A1508), Color(0xFF13253F)],
      ),
      borderColor: AppColors.ember.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(Insets.xl),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const NoorFlame(size: 34),
                    const SizedBox(width: Insets.sm),
                    Text(
                      '${stats.currentStreak}',
                      style: AppType.clock.copyWith(
                        fontSize: 44,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  stats.currentStreak == 1
                      ? 'day current streak'
                      : 'days current streak',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ],
            ),
          ),
          Container(height: 52, width: 1, color: AppColors.navyLine),
          const SizedBox(width: Insets.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${stats.longestStreak}',
                style: AppType.clock.copyWith(
                  fontSize: 30,
                  color: AppColors.goldSoft,
                ),
              ),
              Text(
                'longest',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              const SizedBox(height: Insets.sm),
              Text(
                '${stats.totalPrayers} total',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayRows extends StatelessWidget {
  const _TodayRows({required this.day});

  final PrayerDay day;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Column(
        children: <Widget>[
          for (final PrayerId id in PrayerId.obligatory)
            _TodayRow(id: id, record: day.recordFor(id)),
        ],
      ),
    );
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.id, required this.record});

  final PrayerId id;
  final PrayerRecord record;

  @override
  Widget build(BuildContext context) {
    final ({String label, Color color, IconData icon}) look =
        switch (record.status) {
      PrayerStatus.completed => (
          label: record.confirmedAt == null
              ? 'Confirmed'
              : 'Confirmed ${Fmt.time(record.confirmedAt!)}',
          color: AppColors.emerald,
          icon: Icons.check_circle_rounded,
        ),
      PrayerStatus.awaitingProof => (
          label: 'Photo still needed',
          color: AppColors.amber,
          icon: Icons.pending_actions_rounded,
        ),
      PrayerStatus.missed => (
          label: 'Missed',
          color: AppColors.rose,
          icon: Icons.remove_circle_outline_rounded,
        ),
      PrayerStatus.pending => (
          label: 'Not yet',
          color: AppColors.mistFaint,
          icon: Icons.circle_outlined,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      child: Row(
        children: <Widget>[
          Icon(id.icon, size: 18, color: AppColors.mist),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(id.label, style: AppType.titleSm)),
          Text(
            look.label,
            style: AppType.bodySm.copyWith(color: look.color),
          ),
          const SizedBox(width: Insets.sm),
          Icon(look.icon, size: 18, color: look.color),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.lg,
        horizontal: Insets.md,
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: color),
          const SizedBox(height: Insets.sm),
          Text(value, style: AppType.numeral.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppType.bodySm
                .copyWith(fontSize: 10.5, color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}
