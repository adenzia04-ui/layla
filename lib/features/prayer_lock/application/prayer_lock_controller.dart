import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/prefs_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/data/prayer_day_repository.dart';
import '../../streaks/domain/prayer_day.dart';
import '../data/prayer_lock_platform.dart';
import 'prayer_lock_sync.dart';
import '../data/proof_repository.dart';
import '../domain/prayer_session.dart';

/// Prayers the user has waved away for this window. Kept in memory only: the
/// dismissal lasts until the window closes, and never survives a restart.
final NotifierProvider<DismissedPrayers, Set<String>> dismissedSessionsProvider =
    NotifierProvider<DismissedPrayers, Set<String>>(DismissedPrayers.new);

/// Public because its provider's type signature is public.
class DismissedPrayers extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void dismiss(String key) => state = <String>{...state, key};

  void clear(String key) =>
      state = state.where((String k) => k != key).toSet();
}

/// The prayer window that is currently open, if any.
///
/// A session exists when: the prayer's time started less than 30 minutes ago,
/// the prayer is not yet confirmed, and the user has the focus feature on.
/// A prayer stuck at `awaiting_proof` keeps its session alive for the rest of
/// the window — refusing the photo does not release the lock.
final Provider<PrayerSession?> activeSessionProvider =
    Provider<PrayerSession?>((Ref ref) {
  // Check auth BEFORE touching the schedule. `NoorApp` listens to this
  // provider at the root of the widget tree, and `prayerScheduleProvider`
  // pulls in `placeProvider` — so without this guard the very first thing a
  // new user sees is an iOS location prompt on top of the onboarding screen,
  // before they have been told why Noor wants it or even made an account.
  if (ref.watch(authStateProvider).value == null) return null;

  final PrayerSchedule? schedule = ref.watch(prayerScheduleProvider).value;
  final PrayerDay? day = ref.watch(todayPrayerDayProvider).value;
  final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
  final bool lockEnabled = ref.watch(prayerSettingsProvider).lockEnabled;
  final Set<String> dismissed = ref.watch(dismissedSessionsProvider);

  if (schedule == null || day == null || !lockEnabled) return null;

  for (final PrayerSlot slot in schedule.obligatory) {
    final DateTime endsAt = slot.start.add(kPrayerSessionLength);

    // Only the upper bound is gone: a session opens when the prayer's time
    // arrives and stays open until it is confirmed, however long that takes.
    // Blocked apps stay blocked for exactly as long as this session lives.
    if (now.isBefore(slot.start)) continue;

    final PrayerStatus status = day.recordFor(slot.id).status;

    // Completed and missed both close the session — and closing the session is
    // what lifts the shield. Missing a prayer is an honest answer, so it must
    // be a way out; the cost is the streak, not a phone locked all day.
    if (status == PrayerStatus.completed || status == PrayerStatus.missed) {
      continue;
    }

    // A dismissal only holds while Step 1 has not been pressed. Once the user
    // says "I have prayed", the session cannot be waved away.
    final String key = '${Fmt.dayId(now)}|${slot.id.key}';
    if (dismissed.contains(key) && status != PrayerStatus.awaitingProof) {
      continue;
    }

    return PrayerSession(
      prayer: slot.id,
      startedAt: slot.start,
      endsAt: endsAt,
      status: status,
    );
  }
  return null;
});

/// Progress of the mat-photo upload, 0–1. Null when nothing is uploading.
final NotifierProvider<UploadProgress, double?> proofUploadProgressProvider =
    NotifierProvider<UploadProgress, double?>(UploadProgress.new);

/// Public because its provider's type signature is public.
class UploadProgress extends Notifier<double?> {
  @override
  double? build() => null;

  void set(double? value) => state = value;
}

final AutoDisposeAsyncNotifierProvider<PrayerLockController, void>
    prayerLockControllerProvider =
    AsyncNotifierProvider.autoDispose<PrayerLockController, void>(
  PrayerLockController.new,
);

class PrayerLockController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// **Step 1 — "I Have Prayed".**
  ///
  /// This deliberately does *not* complete the prayer. It records intent and
  /// moves the record to `awaiting_proof`, which keeps the session open until
  /// Step 2 succeeds or the window closes.
  Future<bool> beginConfirmation(PrayerSession session) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => ref.read(prayerDayRepositoryProvider).beginConfirmation(
            prayer: session.prayer,
            scheduledAt: session.startedAt,
          ),
    );
    return !state.hasError;
  }

  /// **Step 2 — the prayer-mat photo.**
  ///
  /// The prayer is marked completed only after the upload has finished
  /// successfully. If the user cancels the picker, denies the camera, kills
  /// the app, or the upload fails, this returns false and the record stays at
  /// `awaiting_proof`.
  Future<bool> submitProof({
    required PrayerSession session,
    required ImageSource source,
  }) async {
    state = const AsyncValue<void>.loading();
    final UploadProgress progress =
        ref.read(proofUploadProgressProvider.notifier);

    state = await AsyncValue.guard(() async {
      final ProofRepository proofs = ref.read(proofRepositoryProvider);

      final XFile? file = await proofs.capture(source: source);
      if (file == null) {
        // Cancelled at the picker — not an error, but not a confirmation.
        throw const AppFailure(
          'A photo of your prayer mat is required to complete this '
          'confirmation.',
          code: 'proof-cancelled',
        );
      }

      progress.set(0);
      final String path = await proofs.save(
        file: file,
        prayer: session.prayer,
        onProgress: progress.set,
      );

      await ref.read(prayerDayRepositoryProvider).completeWithProof(
            prayer: session.prayer,
            proofPath: path,
          );
      progress.set(null);
      await releaseLock();
    });

    if (state.hasError) progress.set(null);
    return !state.hasError;
  }

  /// **"I missed this prayer."**
  ///
  /// Records the prayer as missed and lifts the lock. This is the only release
  /// other than a completed two-step confirmation, and it is deliberately not
  /// free: a missed prayer does not count toward today's progress and breaks
  /// the streak.
  ///
  /// It exists because the alternative is worse. Without it, sleeping through
  /// Fajr leaves the phone locked all day, which pressures an honest user into
  /// photographing a mat for a prayer they did not pray — the exact opposite of
  /// what the friction is for.
  Future<bool> markMissed(PrayerSession session) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(prayerDayRepositoryProvider).markMissed(
            prayer: session.prayer,
            dateId: Fmt.dayId(session.startedAt),
          );
      await releaseLock();
    });
    return !state.hasError;
  }

  /// Steps back from the focus *screen* before Step 1, so the user can reach
  /// the rest of Noor.
  ///
  /// This deliberately does **not** call [releaseLock]: the blocked apps stay
  /// blocked. Only a completed two-step confirmation lifts the shield.
  void dismissForNow(PrayerSession session) {
    // No escape from the focus screen once Step 1 is done — until the window
    // has passed. After that the user must still be able to reach the rest of
    // Noor (their apps stay paused regardless).
    if (session.awaitingProof && !session.isOverdueAt(DateTime.now())) return;
    ref
        .read(dismissedSessionsProvider.notifier)
        .dismiss('${Fmt.dayId(DateTime.now())}|${session.prayer.key}');
  }

  /// Mirrors the session into the OS layer where that is possible at all.
  ///
  /// The OS normally raises the lock on its own from the schedule handed over
  /// by [prayerLockSyncProvider]; this call covers the case where the user
  /// lands on the focus screen mid-window — after a reboot, a fresh install,
  /// or a schedule that had not been registered yet.
  Future<void> engageLock(PrayerSession session) async {
    // The window is over: this must not re-raise the shield.
    //
    // The focus screen calls this every time it appears, and the session
    // outlives the window so the prayer can still be confirmed afterwards.
    // Without this guard the extension would drop the shield at the 30-minute
    // mark and the app would put it straight back the next time the user
    // opened Noor — which is exactly how "the apps never unblock" looked from
    // the outside.
    if (session.isOverdueAt(DateTime.now())) {
      await releaseLock();
      return;
    }

    await ref.read(prefsProvider).setActiveSession(
          '${Fmt.dayId(session.startedAt)}|${session.prayer.key}|'
          '${session.endsAt.millisecondsSinceEpoch}',
        );
    if (!ref.read(appBlockingEnabledProvider)) return;
    try {
      await ref.read(prayerLockPlatformProvider).start(
            prayerLabel: session.prayer.label,
            endsAt: session.endsAt,
          );
    } on Object catch (error) {
      debugPrint('Layla: native lock could not start ($error)');
    }
  }

  /// Drops the lock immediately. Called the instant a prayer is confirmed, so
  /// a shielded app becomes usable again without waiting for the window to
  /// run out.
  Future<void> releaseLock() async {
    await ref.read(prefsProvider).setActiveSession(null);
    try {
      await ref.read(prayerLockPlatformProvider).stop();
    } on Object catch (error) {
      debugPrint('Layla: native lock could not stop ($error)');
    }
  }
}
