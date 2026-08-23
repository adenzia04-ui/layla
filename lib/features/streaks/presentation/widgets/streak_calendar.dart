import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../domain/prayer_day.dart';

/// Five weeks of days, each cell filled in proportion to how many of the five
/// prayers were confirmed — a full cell means a perfect day.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({super.key, required this.history, this.weeks = 5});

  final StreakHistory history;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final DateTime today = Fmt.dayStart(DateTime.now());
    // Wind back to the Monday that starts the earliest visible week.
    final DateTime end = today;
    final int daysToShow = weeks * 7;
    final DateTime start =
        end.subtract(Duration(days: daysToShow - 1 - (7 - end.weekday)));

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String d in const <String>[
              'M', 'T', 'W', 'T', 'F', 'S', 'S',
            ])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: AppType.label.copyWith(color: AppColors.mistFaint),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        for (int week = 0; week < weeks; week++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: <Widget>[
                for (int weekday = 0; weekday < 7; weekday++)
                  Expanded(
                    child: _DayCell(
                      date: start.add(Duration(days: week * 7 + weekday)),
                      today: today,
                      history: history,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Insets.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Less',
              style: AppType.bodySm
                  .copyWith(fontSize: 10, color: AppColors.mistFaint),
            ),
            const SizedBox(width: 6),
            for (int i = 0; i <= 5; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: _fillFor(i),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: AppColors.navyLine.withValues(alpha: 0.8),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              'All five',
              style: AppType.bodySm
                  .copyWith(fontSize: 10, color: AppColors.mistFaint),
            ),
          ],
        ),
      ],
    );
  }
}

Color _fillFor(int completed) {
  if (completed <= 0) return AppColors.navyElevated.withValues(alpha: 0.5);
  if (completed >= PrayerId.obligatory.length) return AppColors.emerald;
  return Color.lerp(
    AppColors.emeraldDeep.withValues(alpha: 0.35),
    AppColors.emerald,
    completed / PrayerId.obligatory.length,
  )!;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.history,
  });

  final DateTime date;
  final DateTime today;
  final StreakHistory history;

  @override
  Widget build(BuildContext context) {
    final bool isFuture = date.isAfter(today);
    final bool isToday = date == today;
    final PrayerDay day = history.dayFor(Fmt.dayId(date));

    return Tooltip(
      message: isFuture
          ? ''
          : '${Fmt.shortDate(date)} · ${day.completedCount}/5 confirmed'
              '${day.tahajjudPrayed ? ' · Tahajjud' : ''}',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: isFuture
                  ? Colors.transparent
                  : _fillFor(day.completedCount),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isToday
                    ? AppColors.gold
                    : AppColors.navyLine.withValues(alpha: isFuture ? 0.4 : 0.9),
                width: isToday ? 1.6 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: day.tahajjudPrayed
                ? const Icon(Icons.star_rounded,
                    size: 10, color: AppColors.goldSoft,)
                : null,
          ),
        ),
      ),
    );
  }
}
