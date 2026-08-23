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

/// The last five weeks, for the streak calendar.
final StreamProvider<StreakHistory> streakHistoryProvider =
    StreamProvider<StreakHistory>(
  (Ref ref) => ref.watch(prayerDayRepositoryProvider).watchHistory(),
);

/// Streak counters straight from the user profile.
final Provider<UserStats> userStatsProvider = Provider<UserStats>(
  (Ref ref) => ref.watch(appUserProvider).value?.stats ?? const UserStats(),
);

/// True when the streak is at risk: the day is not finished and Isha's window
/// is the one currently running.
final Provider<bool> streakAtRiskProvider = Provider<bool>((Ref ref) {
  final PrayerDay? day = ref.watch(todayPrayerDayProvider).value;
  final moment = ref.watch(prayerMomentProvider).value;
  if (day == null || moment == null) return false;
  return !day.isComplete && moment.nextIsTomorrow;
});
