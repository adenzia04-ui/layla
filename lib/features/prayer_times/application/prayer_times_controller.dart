import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/prayer_engine.dart';
import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

final Provider<PrayerEngine> prayerEngineProvider =
    Provider<PrayerEngine>((Ref ref) => const PrayerEngine());

/// The signed-in user's settings, falling back to sensible defaults while the
/// profile document is still loading.
final Provider<PrayerSettings> prayerSettingsProvider =
    Provider<PrayerSettings>(
  (Ref ref) => ref.watch(appUserProvider).value?.settings ?? const PrayerSettings(),
);

/// Resolved position. Refreshing this provider re-reads the GPS.
final FutureProvider<NoorPlace> placeProvider = FutureProvider<NoorPlace>(
  (Ref ref) async {
    final NoorPlace place =
        await ref.watch(locationServiceProvider).currentOrCached();
    // Precise coordinates are written only to the user's own private document.
    unawaited(ref.read(authRepositoryProvider).updateLocation(place));
    return place;
  },
);

/// One tick a second. Everything that counts down watches this.
final StreamProvider<DateTime> clockProvider = StreamProvider<DateTime>(
  (Ref ref) async* {
    yield DateTime.now();
    yield* Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  },
);

/// Date-only view of the clock. Because `DateTime` compares by value, this
/// notifies its listeners exactly once a day instead of once a second.
final Provider<DateTime> todayProvider = Provider<DateTime>((Ref ref) {
  final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
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

final Provider<AsyncValue<PrayerMoment>> prayerMomentProvider =
    Provider<AsyncValue<PrayerMoment>>((Ref ref) {
  final AsyncValue<PrayerSchedule> schedule = ref.watch(prayerScheduleProvider);
  final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
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
  (Ref ref) => ref.watch(prayerScheduleProvider).whenData(
        (PrayerSchedule s) => s.tahajjud,
      ),
);

/// Keeps the OS notification queue in step with the computed schedule.
///
/// Watched once from the app shell; rescheduling is idempotent because each
/// prayer keeps a fixed notification id.
final Provider<void> prayerNotificationSyncProvider = Provider<void>((Ref ref) {
  final AsyncValue<PrayerSchedule> schedule = ref.watch(prayerScheduleProvider);
  final PrayerSettings settings = ref.watch(prayerSettingsProvider);
  final NotificationService notifications =
      ref.watch(notificationServiceProvider);

  final PrayerSchedule? value = schedule.value;
  if (value == null) return;

  unawaited(() async {
    for (int i = 0; i < PrayerId.obligatory.length; i++) {
      final PrayerId id = PrayerId.obligatory[i];
      final PrayerSlot slot = value.slotFor(id);
      if (!settings.notifies(id)) {
        await notifications.cancelPrayer(i);
        continue;
      }
      await notifications.schedulePrayer(
        index: i,
        prayerName: id.label,
        prayerId: id.key,
        at: slot.start,
        openFocusScreen: settings.lockEnabled,
      );
    }
    if (settings.notifies(PrayerId.tahajjud)) {
      await notifications.scheduleTahajjud(at: value.tahajjud.start);
    }
  }());
});
