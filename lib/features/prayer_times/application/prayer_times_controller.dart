import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../cycle/application/cycle_controller.dart';
import '../data/prayer_engine.dart';
import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

final Provider<PrayerEngine> prayerEngineProvider = Provider<PrayerEngine>(
  (Ref ref) => const PrayerEngine(),
);

/// The signed-in user's settings, falling back to sensible defaults while the
/// profile document is still loading.
final Provider<PrayerSettings> prayerSettingsProvider =
    Provider<PrayerSettings>(
      (Ref ref) =>
          ref.watch(appUserProvider).valueOrNull?.settings ??
          const PrayerSettings(),
    );

/// Resolved position. Refreshing this provider re-reads the GPS.
final FutureProvider<NoorPlace> placeProvider = FutureProvider<NoorPlace>((
  Ref ref,
) async {
  final NoorPlace place = await ref
      .watch(locationServiceProvider)
      .currentOrCached();
  // Precise coordinates are written only to the user's own private document.
  unawaited(ref.read(authRepositoryProvider).updateLocation(place));
  return place;
});

/// One tick a second. Everything that counts down watches this.
final StreamProvider<DateTime> clockProvider = StreamProvider<DateTime>((
  Ref ref,
) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now(),
  );
});

/// Date-only view of the clock. Because `DateTime` compares by value, this
/// notifies its listeners exactly once a day instead of once a second.
final Provider<DateTime> todayProvider = Provider<DateTime>((Ref ref) {
  final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Today's computed schedule for the user's position.
final Provider<AsyncValue<PrayerSchedule>> prayerScheduleProvider =
    Provider<AsyncValue<PrayerSchedule>>((Ref ref) {
      final AsyncValue<NoorPlace> place = ref.watch(placeProvider);
      final PrayerSettings settings = ref.watch(prayerSettingsProvider);
      final PrayerEngine engine = ref.watch(prayerEngineProvider);
      final DateTime today = ref.watch(todayProvider);

      return place.whenData(
        (NoorPlace p) => engine.scheduleFor(
          latitude: p.lat,
          longitude: p.lng,
          date: today,
          settings: settings,
        ),
      );
    });

/// Which prayer is running and which is next — recomputed each second but
/// only notifying when the answer actually changes.
@immutable
class PrayerMoment {
  const PrayerMoment({
    required this.current,
    required this.next,
    required this.nextIsTomorrow,
  });

  /// The prayer whose window contains now. Null between midnight and Fajr.
  final PrayerSlot? current;

  /// Always present: after Isha this is tomorrow's Fajr.
  final PrayerSlot next;
  final bool nextIsTomorrow;

  Duration untilNext(DateTime now) => next.start.difference(now);

  @override
  bool operator ==(Object other) =>
      other is PrayerMoment &&
      other.current == current &&
      other.next == next &&
      other.nextIsTomorrow == nextIsTomorrow;

  @override
  int get hashCode => Object.hash(current, next, nextIsTomorrow);
}

final Provider<AsyncValue<PrayerMoment>>
prayerMomentProvider = Provider<AsyncValue<PrayerMoment>>((Ref ref) {
  final AsyncValue<PrayerSchedule> schedule = ref.watch(prayerScheduleProvider);
  final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  final PrayerEngine engine = ref.watch(prayerEngineProvider);
  final PrayerSettings settings = ref.watch(prayerSettingsProvider);

  return schedule.whenData((PrayerSchedule s) {
    final PrayerSlot? next = s.nextAt(now);
    if (next != null) {
      return PrayerMoment(
        current: s.currentAt(now),
        next: next,
        nextIsTomorrow: false,
      );
    }
    // Past Isha — roll over to tomorrow's Fajr.
    final PrayerSchedule tomorrow = engine.scheduleFor(
      latitude: s.latitude,
      longitude: s.longitude,
      date: s.date.add(const Duration(days: 1)),
      settings: settings,
    );
    return PrayerMoment(
      current: s.currentAt(now),
      next: tomorrow.slotFor(PrayerId.fajr),
      nextIsTomorrow: true,
    );
  });
});

/// Tahajjud's window for right now — the one in progress, or the next one.
final Provider<AsyncValue<TahajjudWindow>> tahajjudWindowProvider =
    Provider<AsyncValue<TahajjudWindow>>(
      (Ref ref) => ref
          .watch(prayerScheduleProvider)
          .whenData((PrayerSchedule s) => s.tahajjud),
    );

/// How many days of prayers are queued with the OS at a time.
///
/// One day was not enough, and the failure was silent. The schedule is only
/// refilled while the app is open, so closing it after Isha left nothing at
/// all for Fajr — someone who did not open Layla Pro for a day simply got no
/// reminders that day and had no way to know why.
///
/// Three days at 3 calls x 5 prayers plus Tahajjud is 48 pending
/// notifications against iOS's limit of 64, leaving 16 spare. Four days comes
/// to exactly 64 — not over, but with no headroom at all, and iOS drops the
/// furthest-out notifications silently once the queue is full. The spare
/// slots are the point.
const int _lookaheadDays = 3;

/// Keeps the OS notification queue in step with the computed schedule.
///
/// Watched once from the app shell; rescheduling is idempotent because every
/// call keeps a fixed id, derived from the day and the prayer.
/// Re-queues the reminders whenever Layla Pro comes back to the foreground.
///
/// iOS holds scheduled notifications on behalf of an installed app and drops
/// every one of them the moment that app is removed — so a reinstall leaves the
/// schedule empty, and the only thing that refills it is the sync below, which
/// runs once when the shell is first built. If the app is already in memory
/// that never happens again, and the reminders stay gone.
///
/// Rebuilding them on resume is cheap: the sync writes the same identifiers
/// every time, so re-running it replaces rather than duplicates. It also keeps
/// the three-day lookahead from running out for someone who leaves Layla Pro open
/// for a week.
final Provider<void> notificationRefreshProvider = Provider<void>((Ref ref) {
  final AppLifecycleListener listener = AppLifecycleListener(
    onResume: () => ref.invalidate(todayProvider),
  );
  ref.onDispose(listener.dispose);
});

final Provider<void> prayerNotificationSyncProvider = Provider<void>((Ref ref) {
  final AsyncValue<NoorPlace> place = ref.watch(placeProvider);
  final PrayerSettings settings = ref.watch(prayerSettingsProvider);
  final PrayerEngine engine = ref.watch(prayerEngineProvider);
  final DateTime today = ref.watch(todayProvider);
  final NotificationService notifications = ref.watch(
    notificationServiceProvider,
  );

  // Whether this run has been superseded — a settings change, midnight, or the
  // prayer pause starting. The loop below queues three days of notifications
  // one await at a time, so without this a run that began a moment before the
  // pause started would go on filling the queue after it had been emptied, and
  // the adhan would sound anyway.
  bool stale = false;
  ref.onDispose(() => stale = true);

  // Silence while the prayer pause is on. Every call this app makes is a call
  // to pray, and none of them is owed right now — the reminders, the adhan and
  // the late nudge all go, including Tahajjud.
  //
  // Nothing is torn out: ending the pause re-runs this provider and the whole
  // schedule is queued again, which is also what the cancel here relies on.
  if (ref.watch(cycleActiveProvider)) {
    unawaited(notifications.cancelAll());
    return;
  }

  final NoorPlace? here = place.valueOrNull;
  if (here == null) return;

  unawaited(() async {
    for (int day = 0; day < _lookaheadDays; day++) {
      if (stale) return;
      final PrayerSchedule value = engine.scheduleFor(
        latitude: here.lat,
        longitude: here.lng,
        date: today.add(Duration(days: day)),
        settings: settings,
      );

      for (int i = 0; i < PrayerId.obligatory.length; i++) {
        final PrayerId id = PrayerId.obligatory[i];
        final PrayerSlot slot = value.slotFor(id);

        // Ten slots per day, so tomorrow's Fajr can never overwrite today's.
        // Day 0 is a bare prayer index, which is what `lateReminderSync`
        // cancels against.
        final int index = day * 10 + i;

        if (!settings.notifies(id)) {
          await notifications.cancelPrayer(index);
          await notifications.cancelReminder(index, before: true);
          await notifications.cancelReminder(index, before: false);
          continue;
        }

        // Before the adhan.
        if (settings.remindBefore) {
          await notifications.scheduleReminder(
            index: index,
            prayerName: id.label,
            prayerId: id.key,
            at: slot.start.subtract(Duration(minutes: settings.beforeMinutes)),
            before: true,
            minutes: settings.beforeMinutes,
          );
        } else {
          await notifications.cancelReminder(index, before: true);
        }

        // The adhan itself.
        await notifications.schedulePrayer(
          index: index,
          prayerName: id.label,
          prayerId: id.key,
          at: slot.start,
          openFocusScreen: settings.lockEnabled,
        );

        // And after, if the window is still open and nothing was confirmed.
        // Scheduled unconditionally here and cancelled on confirmation — the
        // OS has no way to ask a question at fire time, so the only way to
        // keep it honest is to withdraw it the moment it stops being true.
        if (settings.remindAfter) {
          await notifications.scheduleReminder(
            index: index,
            prayerName: id.label,
            prayerId: id.key,
            at: slot.start.add(Duration(minutes: settings.afterMinutes)),
            before: false,
            minutes: settings.afterMinutes,
          );
        } else {
          await notifications.cancelReminder(index, before: false);
        }
      }

      if (settings.notifies(PrayerId.tahajjud)) {
        await notifications.scheduleTahajjud(
          at: value.tahajjud.start,
          day: day,
        );
      }
    }
  }());
});
