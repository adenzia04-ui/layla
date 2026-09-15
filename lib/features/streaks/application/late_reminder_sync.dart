import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../cycle/application/cycle_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../domain/prayer_day.dart';
import 'streak_controller.dart';

/// Withdraws the late reminder for any prayer that has been confirmed.
///
/// The OS cannot ask a question when a notification fires — a schedule made an
/// hour ago knows nothing about what has happened since. So "Asr was 30
/// minutes ago, it is not too late" is scheduled for every prayer and taken
/// back the moment it stops being true.
///
/// Hung off the day document rather than the confirmation call, which means a
/// prayer confirmed on another device silences this one too, and the
/// repository stays free of any notion of notifications.
final Provider<void> lateReminderSyncProvider = Provider<void>((Ref ref) {
  final NotificationService notifications = ref.watch(
    notificationServiceProvider,
  );

  // Nothing is late while the prayer pause is on, because nothing is owed.
  // "Asr was 30 minutes ago" is the single unkindest thing this app could say
  // to somebody it has just told not to pray, so the whole band is withdrawn
  // rather than left to the day records — the catch-up may not have reached
  // today yet, and this must not depend on it.
  //
  // Gated, not removed: the pause ending re-runs this provider, and the next
  // schedule puts the reminders back.
  if (ref.watch(cycleActiveProvider)) {
    for (int i = 0; i < PrayerId.obligatory.length; i++) {
      notifications.cancelLateReminder(i);
    }
    return;
  }

  ref.listen<AsyncValue<PrayerDay>>(todayPrayerDayProvider, (
    AsyncValue<PrayerDay>? _,
    AsyncValue<PrayerDay> next,
  ) {
    final PrayerDay? day = next.valueOrNull;
    if (day == null) return;
    for (int i = 0; i < PrayerId.obligatory.length; i++) {
      // `isSettled` rather than `isCompleted`: a prayer the pause covers is
      // finished in the only sense this cares about — there is nothing left to
      // call about — and so is one marked missed, which used to go on being
      // nudged about long after the user had answered honestly.
      if (day.recordFor(PrayerId.obligatory[i]).status.isSettled) {
        notifications.cancelLateReminder(i);
      }
    }
  }, fireImmediately: true);
});
