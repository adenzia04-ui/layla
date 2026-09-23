import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/prefs_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../cycle/application/cycle_controller.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/data/prayer_day_repository.dart';
import '../../streaks/domain/prayer_day.dart';
import '../data/prayer_lock_platform.dart';
import 'prayer_lock_sync.dart';
import '../data/mat_vision.dart';
import '../domain/mat_check.dart';
import '../data/proof_repository.dart';
import '../domain/prayer_session.dart';

/// Prayers the user has waved away for this window. Kept in memory only: the
/// dismissal lasts until the window closes, and never survives a restart.
final NotifierProvider<DismissedPrayers, Set<String>>
dismissedSessionsProvider = NotifierProvider<DismissedPrayers, Set<String>>(
  DismissedPrayers.new,
);

/// Public because its provider's type signature is public.
class DismissedPrayers extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void dismiss(String key) => state = <String>{...state, key};

  void clear(String key) => state = state.where((String k) => k != key).toSet();
}

/// The prayer window that is currently open, if any.
///
/// A session exists when: the prayer's time started less than 30 minutes ago,
/// the prayer is not yet confirmed, and the user has the focus feature on.
/// A prayer stuck at `awaiting_proof` keeps its session alive for the rest of
/// the window — refusing the photo does not release the lock.
final Provider<PrayerSession?>
activeSessionProvider = Provider<PrayerSession?>((Ref ref) {
  // Check auth BEFORE touching the schedule. `NoorApp` listens to this
  // provider at the root of the widget tree, and `prayerScheduleProvider`
  // pulls in `placeProvider` — so without this guard the very first thing a
  // new user sees is an iOS location prompt on top of the onboarding screen,
  // before they have been told why Noor wants it or even made an account.
  if (ref.watch(authStateProvider).valueOrNull == null) return null;

  // No session while the prayer pause is on, so nothing locks her phone, no
  // banner appears and Home offers no choices — none of these prayers is
  // owed. Checked here rather than left to the day records below, because the
  // catch-up may not have reached today yet and the lock must not depend on a
  // write having landed: the pause itself is the fact.
  //
  // Gated, not removed. Ending the pause re-runs this provider and the next
  // prayer whose time is in opens its session exactly as before.
  if (ref.watch(cycleActiveProvider)) return null;

  final PrayerSchedule? schedule = ref
      .watch(prayerScheduleProvider)
      .valueOrNull;
  final PrayerDay? day = ref.watch(todayPrayerDayProvider).valueOrNull;
  final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  final Set<String> dismissed = ref.watch(dismissedSessionsProvider);

  // Deliberately not gated on `lockEnabled` any more.
  //
  // A session is "this prayer's time has come and it is not settled yet" —
  // which is true whether or not the user wants their apps paused. Tying it to
  // the blocking setting meant that turning blocking off also removed the
  // prompt to confirm a prayer at all, and anyone whose `lockEnabled` was
  // false silently lost the home-screen choices, the banner, and any way to
  // record a prayer from the home screen. One flag, three disappearances, no
  // error anywhere.
  //
  // The shield is still the blocking setting's business: `prayerLockSync`
  // hands the OS no windows when it is off, and `engageLock` checks it before
  // raising anything. What a person is asked is now separate from what their
  // phone does about it.
  if (schedule == null || day == null) return null;

  // The prayer whose time it is: the latest one that has begun. It is asked
  // first, at its own time, and it is the only one that asks for the mat.
  // Anything unsettled before it is this morning's backlog and is offered
  // afterwards, one tap each. It used to run the other way round — earliest
  // first — so someone opening the app at Maghrib was walked through Fajr,
  // Dhuhr and Asr, each with its own scan, before Maghrib was even mentioned.
  final List<PrayerSlot> begun = <PrayerSlot>[
    for (final PrayerSlot slot in schedule.obligatory)
      if (!now.isBefore(slot.start)) slot,
  ];
  if (begun.isEmpty) return null;
  final PrayerId currentPrayer = begun.last.id;

  for (final PrayerSlot slot in begun.reversed) {
    final DateTime endsAt = slot.start.add(kPrayerSessionLength);

    final PrayerStatus status = day.recordFor(slot.id).status;

    // Completed and missed both close the session — and closing the session is
    // what lifts the shield. Missing a prayer is an honest answer, so it must
    // be a way out; the cost is the streak, not a phone locked all day.
    //
    // So does excused, which is why this asks `isSettled` rather than naming
    // the two. It used to name them, and a prayer on a paused day therefore
    // matched neither and fell through to open a session: the shield would
    // have risen five times a day over prayers she does not owe, which is the
    // exact opposite of what the pause is for.
    if (status.isSettled) continue;

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
      isCurrent: slot.id == currentPrayer,
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
      () => ref
          .read(prayerDayRepositoryProvider)
          .beginConfirmation(
            prayer: session.prayer,
            scheduledAt: session.startedAt,
          ),
    );
    return !state.hasError;
  }

  /// **Step 2 — the prayer-mat photo.**
  ///
  /// The prayer is marked completed only after the photo has been checked and
  /// stored successfully. If the check rejects it, the app is killed, or the
  /// save fails, this returns false and the record stays at `awaiting_proof`.
  ///
  /// [photo] comes from the scanner, which has already seen a mat in the live
  /// preview — but the full check runs again here regardless. The scanner
  /// judges frames on-device only, for cost; this is the one place a prayer is
  /// allowed to become `completed`, so it is the one place the real gate
  /// belongs.
  Future<bool> submitProof({
    required PrayerSession session,
    required XFile photo,
  }) async {
    state = const AsyncValue<void>.loading();
    final UploadProgress progress = ref.read(
      proofUploadProgressProvider.notifier,
    );

    state = await AsyncValue.guard(() async {
      final ProofRepository proofs = ref.read(proofRepositoryProvider);
      final XFile file = photo;

      // Look at the photo before keeping it. A confident "this is a face" or
      // "this is the sky" is worth catching here, while the camera is still
      // fresh in mind — rejecting it later would mean asking someone to go
      // back and photograph their mat again for no visible reason.
      //
      // Only a confident contradiction blocks. Anything else passes, because
      // no free classifier can actually recognise a prayer mat and this must
      // not become a gate that traps honest people.
      final MatVerdict verdict = await ref
          .read(matVisionProvider)
          .inspect(file.path);
      if (verdict == MatVerdict.looksWrong) {
        throw const AppFailure(
          'That does not look like your prayer mat. Point the camera down at '
          'the mat and take it again.',
          code: 'proof-not-a-mat',
        );
      }

      progress.set(0);
      final String path = await proofs.save(
        file: file,
        prayer: session.prayer,
        onProgress: progress.set,
      );

      await ref
          .read(prayerDayRepositoryProvider)
          .completeWithProof(prayer: session.prayer, proofPath: path);
      progress.set(null);
      await releaseLock();
    });

    if (state.hasError) progress.set(null);
    return !state.hasError;
  }

  /// **"I prayed."** — the whole confirmation, for those without Premium.
  ///
  /// One tap completes the prayer and lifts the lock. Nothing is proven, and
  /// nothing pretends to be: the streak is a promise kept in public.
  Future<bool> confirmWithoutProof(PrayerSession session) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(prayerDayRepositoryProvider)
          .completeWithoutProof(prayer: session.prayer);
      await releaseLock();
    });
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
      await ref
          .read(prayerDayRepositoryProvider)
          .markMissed(
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

  /// **"I will pray when I am home."**
  ///
  /// Lifts the shield and leaves the prayer exactly where it was — pending,
  /// neither prayed nor missed. The window stays open, so confirming later
  /// still counts and still keeps the streak.
  ///
  /// This is the honest option for someone who is driving, at work, or simply
  /// not near a mat. The alternative is what the app used to force: either lie
  /// and press "I have prayed", or mark it missed and break a streak that was
  /// never actually broken. Both are worse than trusting the person, and the
  /// second teaches people that the app punishes honesty.
  Future<bool> deferUntilHome(PrayerSession session) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await releaseLock();
      ref
          .read(dismissedSessionsProvider.notifier)
          .dismiss('${Fmt.dayId(DateTime.now())}|${session.prayer.key}');
    });
    return !state.hasError;
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

    await ref
        .read(prefsProvider)
        .setActiveSession(
          '${Fmt.dayId(session.startedAt)}|${session.prayer.key}|'
          '${session.endsAt.millisecondsSinceEpoch}',
        );
    if (!ref.read(appBlockingEnabledProvider)) return;
    try {
      await ref
          .read(prayerLockPlatformProvider)
          .start(prayerLabel: session.prayer.label, endsAt: session.endsAt);
    } on Object catch (error) {
      debugPrint('Layla Pro: native lock could not start ($error)');
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
      debugPrint('Layla Pro: native lock could not stop ($error)');
    }
  }
}
