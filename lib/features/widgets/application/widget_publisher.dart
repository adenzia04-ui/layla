import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../prayer_lock/application/prayer_lock_sync.dart';
import '../../prayer_lock/application/prayer_lock_controller.dart';
import '../../prayer_lock/domain/prayer_session.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../data/widget_bridge.dart';
import '../domain/widget_snapshot.dart';

/// Builds the snapshot the widgets render.
///
/// Recomputed whenever the schedule, the day's progress, the streak or the
/// lock state changes — not on the clock tick. Countdowns tick inside SwiftUI,
/// so republishing every second would be pure battery cost for no visible gain.
final Provider<WidgetSnapshot?> widgetSnapshotProvider =
    Provider<WidgetSnapshot?>((Ref ref) {
  final PrayerSchedule? schedule = ref.watch(prayerScheduleProvider).value;
  final PrayerMoment? moment = ref.watch(prayerMomentProvider).value;
  if (schedule == null || moment == null) return null;

  final PrayerDay day = ref.watch(todayPrayerDayProvider).value ??
      PrayerDay.empty(Fmt.dayId(DateTime.now()));
  final int streak = ref.watch(userStatsProvider).currentStreak;
  final PrayerSession? session = ref.watch(activeSessionProvider);
  final bool blocking = ref.watch(appBlockingEnabledProvider);
  final String city = ref.watch(placeProvider).value?.city ?? '';

  final PrayerSlot? current = moment.current;

  return WidgetSnapshot(
    city: city.isEmpty ? 'Your location' : city,
    hijri: Fmt.hijri(DateTime.now()),
    latitude: schedule.latitude,
    longitude: schedule.longitude,
    prayers: WidgetSnapshot.prayersFrom(schedule),
    nextKey: moment.next.id.key,
    nextStartsAt: moment.next.start,
    currentKey: current?.id.key ?? '',
    // Before Fajr there is no running prayer, so the gauge measures the stretch
    // from yesterday's Isha instead of collapsing to zero.
    currentStartedAt: current?.start ??
        moment.next.start.subtract(const Duration(hours: 8)),
    streak: streak,
    completedToday: day.completedCount,
    totalToday: PrayerId.obligatory.length,
    locked: session != null && blocking,
    lockedPrayerLabel: session?.prayer.label ?? '',
  );
});

/// Pushes each new snapshot across to iOS. Watched once from the app shell.
final Provider<void> widgetSyncProvider = Provider<void>((Ref ref) {
  final WidgetSnapshot? snapshot = ref.watch(widgetSnapshotProvider);
  if (snapshot == null) return;

  final WidgetBridge bridge = ref.watch(widgetBridgeProvider);

  // The Live Activity only exists while a prayer window is open — a permanent
  // one would be clutter on the Lock Screen. It is also the only surface that
  // can show the streak, since `Activity` carries state straight from the app
  // and needs no App Group.
  if (snapshot.locked) {
    unawaited(bridge.startLiveActivity(snapshot));
  } else {
    unawaited(bridge.endLiveActivity());
  }

  // Home-screen widgets compute their own times, but the streak and today's
  // progress live behind the login, so they have to be handed over. This also
  // redraws the widgets, so no separate reload is needed.
  unawaited(bridge.publishSnapshot(snapshot));
});
