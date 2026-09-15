import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../data/prayer_day_repository.dart';
import '../domain/prayer_day.dart';

/// Today's prayer record, live.
final StreamProvider<PrayerDay> todayPrayerDayProvider =
    StreamProvider<PrayerDay>((Ref ref) {
      // Depending on todayProvider makes this roll over at midnight on its own.
      final String dateId = Fmt.dayId(ref.watch(todayProvider));
      return ref.watch(prayerDayRepositoryProvider).watchDay(dateId);
    });

/// This calendar year, for the year view.
///
/// Keyed off [todayProvider], so at midnight on 31 December the stream is
/// simply rebuilt for the new year — nothing to reset, nothing to remember.
final StreamProvider<StreakHistory> streakHistoryProvider =
    StreamProvider<StreakHistory>((Ref ref) {
      final int year = ref.watch(todayProvider).year;
      return ref.watch(prayerDayRepositoryProvider).watchYear(year);
    });

/// Streak counters straight from the user profile.
final Provider<UserStats> userStatsProvider = Provider<UserStats>(
  (Ref ref) =>
      ref.watch(appUserProvider).valueOrNull?.stats ?? const UserStats(),
);

/// True when the streak is at risk: the day is not finished and Isha's window
/// is the one currently running.
///
/// Never on a day the prayer pause covers. An excused day is deliberately not
/// "complete" — there was nothing to complete — so without this it would read
/// as an unfinished day and spend every evening of the pause warning her about
/// a streak that is in no danger at all.
final Provider<bool> streakAtRiskProvider = Provider<bool>((Ref ref) {
  final PrayerDay? day = ref.watch(todayPrayerDayProvider).valueOrNull;
  final moment = ref.watch(prayerMomentProvider).valueOrNull;
  if (day == null || moment == null) return false;
  if (day.excused) return false;
  return !day.isComplete && moment.nextIsTomorrow;
});
