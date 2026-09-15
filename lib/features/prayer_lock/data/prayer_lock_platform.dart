import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayer_times/domain/prayer_settings.dart';

/// Which native mechanism, if any, can hold other apps back on this device.
enum LockKind {
  /// No native lock — the in-app focus screen is the whole feature.
  none,

  /// Foreground service + usage polling + overlay. Best-effort, escapable.
  androidSoftLock,

  /// Apple Screen Time: FamilyControls + ManagedSettings + DeviceActivity.
  /// A real shield, gated behind an Apple-granted entitlement.
  iosScreenTime;

  String get label => switch (this) {
    LockKind.none => 'Not available',
    LockKind.androidSoftLock => 'Soft lock',
    LockKind.iosScreenTime => 'Screen Time',
  };
}

/// One prayer window handed to the OS so it can raise and drop the shield on
/// its own — the phone does the timing, not Noor.
@immutable
class LockWindow {
  const LockWindow({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
  });

  /// Stable per-prayer id, e.g. `fajr`. Reusing it replaces the old schedule
  /// rather than stacking a second one.
  final String id;
  final String label;
  final DateTime start;
  final DateTime end;

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'label': label,
    'startMillis': start.millisecondsSinceEpoch,
    'endMillis': end.millisecondsSinceEpoch,
  };
}

/// What the native lock is currently allowed to do.
@immutable
class LockPermissions {
  const LockPermissions({
    this.kind = LockKind.none,
    this.usageAccess = false,
    this.overlay = false,
    this.authorized = false,
    this.hasSelection = false,
  });

  final LockKind kind;

  /// Android — PACKAGE_USAGE_STATS: notice that another app came forward.
  final bool usageAccess;

  /// Android — SYSTEM_ALERT_WINDOW: return to Noor from the background.
  final bool overlay;

  /// iOS — the user granted Screen Time authorisation to Noor.
  final bool authorized;

  /// iOS — the user has picked at least one app or category to pause.
  final bool hasSelection;

  bool get supported => kind != LockKind.none;

  /// True when everything the platform needs is in place.
  bool get isComplete => switch (kind) {
    LockKind.none => false,
    LockKind.androidSoftLock => usageAccess && overlay,
    LockKind.iosScreenTime => authorized && hasSelection,
  };

  /// The next thing the user has to do, or null when nothing is missing.
  String? get nextStep => switch (kind) {
    LockKind.none => null,
    LockKind.androidSoftLock when !usageAccess => 'Allow usage access',
    LockKind.androidSoftLock when !overlay => 'Allow display over other apps',
    LockKind.iosScreenTime when !authorized => 'Allow Screen Time',
    LockKind.iosScreenTime when !hasSelection => 'Choose apps to pause',
    _ => null,
  };
}

/// The OS-level half of the prayer lock.
///
/// Read `docs/PRAYER_LOCK_LIMITATIONS.md` before changing anything here.
///
/// No Dart code can block apps on either platform. The two native routes are
/// completely different, and this interface is the only place that difference
/// is allowed to exist:
///
/// * **Android** — [AndroidSoftLock]. A foreground service returns the user to
///   Noor when another app comes forward. Best-effort: the user can escape it,
///   and OEM battery managers can stop it.
/// * **iOS** — [IosScreenTimeLock]. Apple's Screen Time API genuinely shields
///   the apps the user chose, for the length of the window. Requires the
///   Family Controls (Distribution) entitlement and native app extensions.
/// * **Anything else** — [UnsupportedPrayerLock], every call a no-op.
///
/// Noor's real enforcement is the two-step confirmation, which lives entirely
/// inside the app and works identically everywhere.
abstract interface class PrayerLockPlatform {
  LockKind get kind;

  Future<LockPermissions> permissions();

  // ── Android grants ───────────────────────────────────────────────────
  Future<void> requestUsageAccess();
  Future<void> requestOverlay();

  // ── iOS grants ───────────────────────────────────────────────────────
  /// Presents Apple's Screen Time authorisation prompt.
  /// Returns `null` when Screen Time was granted, or the reason it was not.
  ///
  /// A bool told the settings screen only that the answer was no, and every
  /// way of getting there has a different fix — Screen Time switched off in
  /// iOS Settings, another app already managing it, a Family Sharing
  /// restriction. The user saw one red cross for all of them.
  Future<String?> requestAuthorization();

  /// Presents Apple's own app picker. Noor never learns which apps were
  /// chosen — the system hands back opaque tokens.
  Future<bool> chooseApps();

  /// Hands the day's prayer windows to the OS so the shield rises and falls
  /// without Noor having to be running. Android ignores the windows but still
  /// needs [scope]. Passing an empty list clears everything.
  Future<void> scheduleWindows(
    List<LockWindow> windows, {
    BlockScope scope = BlockScope.everything,
  });

  /// Engages the lock right now, for a window already in progress.
  Future<void> start({required String prayerLabel, required DateTime endsAt});

  /// Releases the lock immediately — called the moment a prayer is confirmed.
  Future<void> stop();

  /// Runs a real block window right now and returns when it will lift, or null
  /// where the platform cannot do it. Used to prove the shield rises *and*
  /// falls without waiting for a prayer.
  Future<DateTime?> startTestWindow();

  /// Schedules a real, future window so iOS — not Layla Pro — raises the shield.
  /// Returns when it should fire, or null if it could not be scheduled.
  Future<DateTime?> startTriggerTest();
}

final Provider<PrayerLockPlatform> prayerLockPlatformProvider =
    Provider<PrayerLockPlatform>((Ref ref) {
      if (Platform.isAndroid) return const AndroidSoftLock();
      if (Platform.isIOS) return const IosScreenTimeLock();
      return const UnsupportedPrayerLock();
    });

/// Shared channel — the native side of each platform answers the same names.
const MethodChannel _channel = MethodChannel('com.noorapp.noor/prayer_lock');

/// What the last self-test reported, for the settings screen to show.
Map<String, Object?>? lastSelfTestReport;

Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
  try {
    return await _channel.invokeMethod<T>(method, args);
  } on PlatformException catch (error) {
    debugPrint('Layla Pro: prayer lock "$method" failed — ${error.message}');
    return null;
  } on MissingPluginException {
    // The native module is not installed in this build. The in-app focus
    // screen still works; nothing else should break.
    debugPrint('Layla Pro: prayer lock native module not installed');
    return null;
  }
}

/// Android: foreground service + usage polling + overlay.
/// Implemented in `platform/kotlin/PrayerLockService.kt`.
class AndroidSoftLock implements PrayerLockPlatform {
  const AndroidSoftLock();

  @override
  LockKind get kind => LockKind.androidSoftLock;

  @override
  Future<LockPermissions> permissions() async {
    final Map<Object?, Object?>? result = await _invoke<Map<Object?, Object?>>(
      'permissions',
    );
    if (result == null) return const LockPermissions();
    return LockPermissions(
      kind: result['supported'] as bool? ?? false
          ? LockKind.androidSoftLock
          : LockKind.none,
      usageAccess: result['usageAccess'] as bool? ?? false,
      overlay: result['overlay'] as bool? ?? false,
    );
  }

  @override
  Future<void> requestUsageAccess() => _invoke<void>('requestUsageAccess');

  @override
  Future<void> requestOverlay() => _invoke<void>('requestOverlay');

  @override
  Future<String?> requestAuthorization() async =>
      'Screen Time is only available on iOS.';

  @override
  Future<bool> chooseApps() async => false;

  /// Android schedules nothing ahead of time: the service starts when a
  /// window opens. Scope is irrelevant here — the soft lock returns the user
  /// to Noor rather than shielding a chosen set.
  @override
  Future<void> scheduleWindows(
    List<LockWindow> windows, {
    BlockScope scope = BlockScope.everything,
  }) async {}

  @override
  Future<void> start({required String prayerLabel, required DateTime endsAt}) =>
      _invoke<void>('start', <String, Object?>{
        'prayerLabel': prayerLabel,
        'endsAtMillis': endsAt.millisecondsSinceEpoch,
      });

  @override
  Future<void> stop() => _invoke<void>('stop');

  /// Only the iOS Screen Time path can prove itself this way.
  @override
  Future<DateTime?> startTriggerTest() async => null;

  @override
  Future<DateTime?> startTestWindow() async => null;
}

/// iOS: Apple's Screen Time API.
/// Implemented in `platform/ios/Runner/PrayerLockBridge.swift` plus the
/// `NoorDeviceActivityMonitor` app extension.
///
/// Everything here is a no-op until the app is built with the Family Controls
/// entitlement and the extension target — `permissions()` reports
/// `LockKind.none` in that case and the settings screen says so.
class IosScreenTimeLock implements PrayerLockPlatform {
  const IosScreenTimeLock();

  @override
  LockKind get kind => LockKind.iosScreenTime;

  @override
  Future<LockPermissions> permissions() async {
    final Map<Object?, Object?>? result = await _invoke<Map<Object?, Object?>>(
      'permissions',
    );
    if (result == null) return const LockPermissions();
    return LockPermissions(
      kind: result['supported'] as bool? ?? false
          ? LockKind.iosScreenTime
          : LockKind.none,
      authorized: result['authorized'] as bool? ?? false,
      hasSelection: result['hasSelection'] as bool? ?? false,
    );
  }

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<void> requestOverlay() async {}

  @override
  Future<String?> requestAuthorization() async {
    // Not _invoke: that swallows PlatformException, which is exactly where
    // the native side now puts the reason.
    try {
      final bool ok =
          await _channel.invokeMethod<bool>('requestAuthorization') ?? false;
      return ok ? null : 'Screen Time access was not granted.';
    } on PlatformException catch (error) {
      return error.message ?? 'Screen Time refused the request.';
    } on MissingPluginException {
      return 'This build cannot manage Screen Time.';
    }
  }

  @override
  Future<bool> chooseApps() async => await _invoke<bool>('chooseApps') ?? false;

  @override
  @override
  Future<DateTime?> startTriggerTest() async {
    final int? startMillis = await _invoke<int>('startTriggerTest');
    return startMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(startMillis);
  }

  @override
  Future<DateTime?> startTestWindow() async {
    final Map<Object?, Object?>? report = await _invoke<Map<Object?, Object?>>(
      'startTestWindow',
    );
    // Printed, not swallowed. Three rounds of this bug were spent guessing
    // which precondition was false.
    if (report != null) debugPrint('Layla Pro: self-test — $report');
    lastSelfTestReport = report?.map(
      (Object? k, Object? v) => MapEntry<String, Object?>('$k', v),
    );
    final int? endMillis = report?['endMillis'] as int?;
    if (endMillis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(endMillis);
  }

  @override
  Future<void> scheduleWindows(
    List<LockWindow> windows, {
    BlockScope scope = BlockScope.everything,
  }) => _invoke<void>('scheduleWindows', <String, Object?>{
    'windows': windows.map((LockWindow w) => w.toMap()).toList(),
    'scope': scope.key,
  });

  @override
  Future<void> start({required String prayerLabel, required DateTime endsAt}) =>
      _invoke<void>('start', <String, Object?>{
        'prayerLabel': prayerLabel,
        'endsAtMillis': endsAt.millisecondsSinceEpoch,
      });

  @override
  Future<void> stop() => _invoke<void>('stop');
}

/// Any platform with no native lock. Every call is a no-op; the settings
/// screen reports "not available in this version" rather than pretending.
class UnsupportedPrayerLock implements PrayerLockPlatform {
  const UnsupportedPrayerLock();

  @override
  LockKind get kind => LockKind.none;

  @override
  Future<LockPermissions> permissions() async => const LockPermissions();

  @override
  Future<void> requestUsageAccess() async {}

  @override
  Future<void> requestOverlay() async {}

  @override
  Future<String?> requestAuthorization() async =>
      'Screen Time is not available in this build.';

  @override
  Future<bool> chooseApps() async => false;

  @override
  Future<void> scheduleWindows(
    List<LockWindow> windows, {
    BlockScope scope = BlockScope.everything,
  }) async {}

  @override
  Future<void> start({
    required String prayerLabel,
    required DateTime endsAt,
  }) async {}

  @override
  Future<void> stop() async {}

  /// Only the iOS Screen Time path can prove itself this way.
  @override
  Future<DateTime?> startTriggerTest() async => null;

  @override
  Future<DateTime?> startTestWindow() async => null;
}
