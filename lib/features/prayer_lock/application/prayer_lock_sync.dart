import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../data/prayer_lock_platform.dart';
import '../domain/prayer_session.dart';

/// Reactive mirror of the "block other apps" preference.
///
/// `PrefsService` is a synchronous façade with no change notification, so the
/// toggle needs its own notifier for the settings screen and the schedule sync
/// to both react to it.
final NotifierProvider<AppBlockingToggle, bool> appBlockingEnabledProvider =
    NotifierProvider<AppBlockingToggle, bool>(AppBlockingToggle.new);

class AppBlockingToggle extends Notifier<bool> {
  @override
  bool build() => ref.watch(prefsProvider).appBlockingEnabled;

  Future<void> set({required bool enabled}) async {
    await ref.read(prefsProvider).setAppBlockingEnabled(enabled);
    state = enabled;
  }
}

/// The current native lock's capabilities. Invalidate it after the user comes
/// back from a system settings screen or Apple's picker.
final FutureProvider<LockPermissions> lockPermissionsProvider =
    FutureProvider<LockPermissions>(
  (Ref ref) => ref.watch(prayerLockPlatformProvider).permissions(),
);

/// Hands today's five prayer windows to the OS.
///
/// On iOS this is what makes the lock work while Noor is closed: the system
/// raises the Screen Time shield at the start of each window and drops it 30
/// minutes later, without the app running. On Android it is a no-op — the
/// service is started when the window actually opens.
///
/// Watched once from the app shell, so it re-runs whenever the times, the
/// settings or the toggle change.
final Provider<void> prayerLockSyncProvider = Provider<void>((Ref ref) {
  final PrayerSchedule? schedule = ref.watch(prayerScheduleProvider).value;
  final PrayerSettings settings = ref.watch(prayerSettingsProvider);
  final bool blockingEnabled = ref.watch(appBlockingEnabledProvider);
  final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);

  if (platform.kind == LockKind.none || schedule == null) return;

  // Passing an empty list clears every registered window — that is how the
  // user turning the toggle off actually releases the shield.
  if (!blockingEnabled || !settings.lockEnabled) {
    unawaited(platform.scheduleWindows(const <LockWindow>[]));
    return;
  }

  // Only the prayers the user left switched on under "Active for".
  final List<LockWindow> windows = <LockWindow>[
    for (final PrayerSlot slot in schedule.obligatory)
      if (settings.blocks(slot.id))
        LockWindow(
          id: slot.id.key,
          label: slot.id.label,
          start: slot.start,
          end: slot.start.add(kPrayerSessionLength),
        ),
  ];

  unawaited(
    platform.scheduleWindows(windows, scope: settings.blockScope),
  );

});

/// Drops the shield once every window for the day has passed.
///
/// Separate from [prayerLockSyncProvider] on purpose. This one has to watch the
/// clock, and the clock ticks every second — folding it into the sync provider
/// would re-register the DeviceActivity schedule once a second, restarting
/// intervals mid-window. `select` collapses those ticks to a single boolean, so
/// this rebuilds only when a window actually opens or closes.
///
/// The extension's `intervalDidEnd` is the primary release and works while Noor
/// is closed; this covers the cases it cannot — an extension killed early, or a
/// window registered before a reboot that never fires. Being left blocked with
/// no way out from inside Noor is the one failure worth paying for twice.
final Provider<void> prayerLockReleaseProvider = Provider<void>((Ref ref) {
  final PrayerSchedule? schedule = ref.watch(prayerScheduleProvider).value;
  final PrayerSettings settings = ref.watch(prayerSettingsProvider);
  final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);

  if (platform.kind == LockKind.none || schedule == null) return;

  final bool anyWindowOpen =
      ref.watch(clockProvider.select((AsyncValue<DateTime> value) {
    final DateTime now = value.value ?? DateTime.now();
    return schedule.obligatory.any((PrayerSlot slot) {
      if (!settings.blocks(slot.id)) return false;
      final DateTime end = slot.start.add(kPrayerSessionLength);
      return !now.isBefore(slot.start) && now.isBefore(end);
    });
  }),);

  if (!anyWindowOpen) unawaited(platform.stop());
});
