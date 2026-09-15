import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/domain/app_user.dart';
import '../../cycle/presentation/cycle_pause_control.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../application/streak_controller.dart';
import '../domain/prayer_day.dart';
import 'widgets/year_of_prayer.dart';

class StreakScreen extends ConsumerStatefulWidget {
  const StreakScreen({super.key});

  @override
  ConsumerState<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends ConsumerState<StreakScreen> {
  /// The day opened from the year view, if any.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final UserStats stats = ref.watch(userStatsProvider);
    // Read against today's date: a chain whose last finished day is older than
    // yesterday has already been broken, whatever the stored number says.
    final DateTime today = ref.watch(todayProvider);
    final int streak = stats.streakOn(today);
    final AsyncValue<StreakHistory> history = ref.watch(streakHistoryProvider);
    // Drawn as the pause will leave it rather than as the day document
    // currently reads. Between the profile knowing a pause is on and the
    // catch-up write landing — a network round trip, and offline possibly not
    // that session at all — these five would otherwise be labelled "Not yet":
    // five prayers presented as still expected of her, on a day she is not
    // praying, on the very screen she opened to check the pause had not cost
    // her streak.
    final PrayerDay todayDay = cycleDayFor(
      ref,
      ref.watch(todayPrayerDayProvider).valueOrNull ??
          PrayerDay.empty(Fmt.dayId(today)),
    );

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
          _StreakHeadline(stats: stats, streak: streak),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: "Today's progress"),
          _TodayRows(day: todayDay),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Your year'),
          history.when(
            loading: () => const SizedBox(height: 200, child: LoadingView()),
            // The real message, not a polite constant. "Your history could
            // not be loaded" is true of a missing index, a permission rule and
            // a dropped connection alike, and those are fixed in three
            // different places — so the one fact that distinguishes them is
            // put on screen rather than swallowed.
            error: (Object error, StackTrace stack) => ErrorView(
              message: error is FirebaseException
                  ? 'Your history could not be loaded — Firestore said '
                        '"${error.code}".'
                  : 'Your history could not be loaded ($error).',
              onRetry: () => ref.invalidate(streakHistoryProvider),
            ),
            data: (StreakHistory h) => _YearSection(
              history: h,
              today: today,
              selected: _selected,
              onSelect: (DateTime? d) => setState(() => _selected = d),
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
                  'Prayed" and scanning your prayer mat. Missing '
                  'either step leaves the prayer unconfirmed and ends the '
                  'streak at the end of that day.',
                  style: AppType.bodySm.copyWith(
                    color: AppColors.mist,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The year of dots, the year's numbers, and whichever day is open.
class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.history,
    required this.today,
    required this.selected,
    required this.onSelect,
  });

  final StreakHistory history;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelect;

  /// Moves the open day by [days], within the year and never past today.
  ///
  /// The dots are too small to be sure of a finger, so the arrows are the
  /// precise way in: with nothing open, the first press opens today; from
  /// there the arrows walk the grid the way it is drawn — up and down one
  /// day within the week's column, left and right one week across.
  void _step(int days) {
    final DateTime last = today.year == history.year
        ? Fmt.dayStart(today)
        : DateTime(history.year, 12, 31);
    final DateTime first = DateTime(history.year, 1, 1);
    final DateTime? open = selected;
    DateTime next = open == null
        ? last
        : DateTime(open.year, open.month, open.day + days);
    if (next.isBefore(first)) next = first;
    if (next.isAfter(last)) next = last;
    if (next == open) return;
    HapticFeedback.selectionClick();
    onSelect(next);
  }

  @override
  Widget build(BuildContext context) {
    final int year = history.year;
    final DateTime jan1 = DateTime.utc(year, 1, 1);
    final int daysInYear = DateTime.utc(year + 1, 1, 1).difference(jan1).inDays;
    final int dayOfYear = today.year == year
        ? DateTime.utc(
                today.year,
                today.month,
                today.day,
              ).difference(jan1).inDays +
              1
        : daysInYear;
    // What was owed, not five times every day of the year. A paused day
    // contributes nothing to `totalConfirmed`, so counting it in full here
    // would hold a woman who prayed everything she owed permanently short of
    // 100% — the app putting a number on a debt that does not exist.
    final int possible = history.owedPrayers(dayOfYear);
    final double share = possible == 0
        ? 0
        : (history.totalConfirmed / possible).clamp(0, 1);
    final DateTime? open = selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NightCard(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('$year', style: AppType.titleMd),
                  const Spacer(),
                  Text(
                    'Day $dayOfYear of $daysInYear',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              YearOfPrayer(
                history: history,
                today: today,
                selected: open,
                onSelect: onSelect,
              ),
              const SizedBox(height: Insets.lg),
              Row(
                children: <Widget>[
                  CircleIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'A week back',
                    onPressed: () => _step(-7),
                  ),
                  const SizedBox(width: Insets.xs),
                  CircleIconButton(
                    icon: Icons.keyboard_arrow_up_rounded,
                    tooltip: 'A day back',
                    onPressed: () => _step(-1),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Text(
                          open == null
                              ? 'Pick a day'
                              : Fmt.dayStart(open) == Fmt.dayStart(today)
                              ? 'Today'
                              : Fmt.shortDate(open),
                          textAlign: TextAlign.center,
                          style: AppType.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '‹ › a week   ˄ ˅ a day',
                          textAlign: TextAlign.center,
                          style: AppType.bodySm.copyWith(
                            fontSize: 10,
                            color: AppColors.mistFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleIconButton(
                    icon: Icons.keyboard_arrow_down_rounded,
                    tooltip: 'A day forward',
                    onPressed: () => _step(1),
                  ),
                  const SizedBox(width: Insets.xs),
                  CircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'A week forward',
                    onPressed: () => _step(7),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              _YearBar(share: share),
              const SizedBox(height: Insets.md),
              const YearLegend(),
            ],
          ),
        ),
        const SizedBox(height: Insets.md),
        // The open day slides in under the year and grows the page to fit;
        // switching days crossfades rather than jumping.
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            child: open == null
                ? Padding(
                    key: const ValueKey<String>('hint'),
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                    child: Text(
                      'Tap a dot, or slide a finger across the year, to look '
                      'back at any day.',
                      textAlign: TextAlign.center,
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                      ),
                    ),
                  )
                : _DayDetail(
                    key: ValueKey<DateTime>(open),
                    date: open,
                    day: history.dayFor(Fmt.dayId(open)),
                    isToday: Fmt.dayStart(open) == Fmt.dayStart(today),
                    onClose: () => onSelect(null),
                  ),
          ),
        ),
        const SizedBox(height: Insets.xl),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatTile(
                label: 'Perfect days',
                value: '${history.perfectDays}',
                icon: Icons.verified_rounded,
                color: AppColors.emerald,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: _StatTile(
                label: 'Prayers confirmed',
                value: '${history.totalConfirmed}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: _StatTile(
                label: 'Tahajjud nights',
                value: '${history.tahajjudNights}',
                icon: Icons.bedtime_outlined,
                color: AppColors.goldSoft,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// How much of the year's prayers so far have been confirmed, as a thin bar.
class _YearBar extends StatelessWidget {
  const _YearBar({required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    final int pct = (share * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(
                  child: ColoredBox(color: AppColors.navyLine),
                ),
                FractionallySizedBox(
                  widthFactor: share,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[AppColors.goldDim, AppColors.gold],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "$pct% of this year's prayers confirmed so far",
          style: AppType.bodySm.copyWith(fontSize: 11, color: AppColors.mist),
        ),
      ],
    );
  }
}

/// One day, opened from the year: each prayer, and Tahajjud if it was prayed.
class _DayDetail extends StatelessWidget {
  const _DayDetail({
    super.key,
    required this.date,
    required this.day,
    required this.isToday,
    required this.onClose,
  });

  final DateTime date;
  final PrayerDay day;
  final bool isToday;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final int n = day.completedCount;
    final int all = PrayerId.obligatory.length;
    final ({String text, Color color}) summary = switch (n) {
      // The pause covers this day: nothing was owed on it, so there is nothing
      // to be short of. Placed before the counting arms on purpose — a pause
      // that began in the evening leaves the Fajr she prayed that morning
      // confirmed, and "1 of 5 confirmed" in amber would present the four she
      // was never asked to pray as outstanding. These prayers are not made up
      // (Sahih Muslim 335) and no screen may imply a debt. "Paused" adds
      // nothing a passer-by could not already read: the five rows below carry
      // that exact word.
      _ when day.excused => (text: 'Paused', color: AppColors.mistFaint),
      _ when n >= all => (text: 'A perfect day', color: AppColors.emerald),
      _ when n > 0 => (text: '$n of $all confirmed', color: AppColors.amber),
      _ when day.anyMissed => (text: 'Missed', color: AppColors.rose),
      _ => (
        text: isToday ? 'Not yet' : 'Nothing recorded',
        color: AppColors.mistFaint,
      ),
    };

    return NightCard(
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.md,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      isToday ? 'Today' : Fmt.dayDate(date),
                      style: AppType.titleMd,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.hijri(date),
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: summary.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text(
                  summary.text,
                  style: AppType.label.copyWith(color: summary.color),
                ),
              ),
              const SizedBox(width: Insets.xs),
              IconButton(
                onPressed: onClose,
                tooltip: 'Close',
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.mistFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          for (final PrayerId id in PrayerId.obligatory)
            _TodayRow(id: id, record: day.recordFor(id), past: !isToday),
          if (day.tahajjudPrayed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppColors.goldSoft,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(child: Text('Tahajjud', style: AppType.titleSm)),
                  Text(
                    day.tahajjudAt == null
                        ? 'Prayed'
                        : 'Prayed ${Fmt.time(day.tahajjudAt!)}',
                    style: AppType.bodySm.copyWith(color: AppColors.goldSoft),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Insets.xs),
        ],
      ),
    );
  }
}

class _StreakHeadline extends StatelessWidget {
  const _StreakHeadline({required this.stats, required this.streak});

  final UserStats stats;

  /// Checked against today's date rather than read straight from storage —
  /// see [UserStats.streakOn].
  final int streak;

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
                      '$streak',
                      style: AppType.clock.copyWith(
                        fontSize: 44,
                        color: AppColors.cream,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  streak == 1 ? 'day current streak' : 'days current streak',
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
  const _TodayRow({required this.id, required this.record, this.past = false});

  final PrayerId id;
  final PrayerRecord record;

  /// A pending prayer on a day that has gone is "not confirmed", not "not
  /// yet" — there is no yet left.
  final bool past;

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
            label: past ? 'Not confirmed' : 'Photo still needed',
            color: past ? AppColors.mistFaint : AppColors.amber,
            icon: past ? Icons.circle_outlined : Icons.pending_actions_rounded,
          ),
          PrayerStatus.missed => (
            label: 'Missed',
            color: AppColors.rose,
            icon: Icons.remove_circle_outline_rounded,
          ),
          // Covered by the prayer pause. "Paused", never "missed" and never
          // "not confirmed": this prayer was not owed, and a history screen
          // that implies otherwise is the app telling a woman she is behind
          // on prayers she never had to make up.
          PrayerStatus.excused => (
            label: 'Paused',
            color: AppColors.mistFaint,
            icon: Icons.remove_rounded,
          ),
          PrayerStatus.pending => (
            label: past ? 'Not confirmed' : 'Not yet',
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
          Text(look.label, style: AppType.bodySm.copyWith(color: look.color)),
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
            style: AppType.bodySm.copyWith(
              fontSize: 10.5,
              color: AppColors.mistFaint,
            ),
          ),
        ],
      ),
    );
  }
}
