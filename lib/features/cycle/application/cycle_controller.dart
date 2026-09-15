import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../onboarding/domain/journey_answers.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../data/cycle_repository.dart';
import '../domain/cycle.dart';

/// The pause as it stands right now, straight off the profile.
///
/// [Cycle] compares by value, so this notifies its listeners when a pause
/// starts or ends and stays quiet through every other change to the user
/// document — including the ones the catch-up below makes.
final Provider<Cycle> cycleProvider = Provider<Cycle>(
  (Ref ref) => ref.watch(appUserProvider).valueOrNull?.cycle ?? Cycle.none,
);

/// Whether a prayer pause is on.
///
/// The single line everything that would otherwise ask her to pray watches:
/// the reminders, the late nudge, the app lock and the focus session. Gated
/// rather than torn out, so ending the pause brings all of them back with no
/// further bookkeeping.
final Provider<bool> cycleActiveProvider = Provider<bool>(
  (Ref ref) => ref.watch(cycleProvider).isActive,
);

/// How many days the pause has run, or 0 when none is on. "Day 3".
final Provider<int> cycleDayCountProvider = Provider<int>(
  (Ref ref) => ref.watch(cycleProvider).dayCount(ref.watch(todayProvider)),
);

/// Whether the pause has run long enough that the app may ask — once, gently —
/// whether it has ended. Asking is all it may ever do: see [Cycle.askAfterDays].
final Provider<bool> cycleLongerThanUsualProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(cycleProvider).isLongerThanUsual(ref.watch(todayProvider)),
);

/// Whether the person using the app answered "sister" to the one onboarding
/// question that decides whether the pause is ever offered.
///
/// The profile first, because that is the copy that survives signing out. The
/// local onboarding answer is the fallback, and it is there for everybody who
/// onboarded before the answer was written to Firestore at all — without it
/// this feature would appear for nobody already using the app, and there is
/// nothing on screen that would explain why.
final Provider<bool> isSisterProvider = Provider<bool>((Ref ref) {
  final String? stored = ref.watch(appUserProvider).valueOrNull?.gender;
  if (Gender.isValid(stored)) return Gender.isSister(stored);

  final String? answered = JourneyAnswers.decode(
    ref.watch(prefsProvider).journeyAnswers,
  ).gender;
  return Gender.isSister(answered);
});

/// Copies the onboarding gender answer onto the profile when it is missing.
///
/// Signing in writes it too, but only from the sign-in that happens after
/// onboarding. This is for everybody who already had an account before the
/// answer was written to Firestore at all: their profile has no gender, their
/// phone still has the answer, and one app open moves it across. Without it
/// the fallback in [isSisterProvider] would be carrying those accounts
/// forever, and the first sign-out would take the answer with it.
///
/// Writes only into the gap. A profile that already holds a valid answer is
/// never overwritten by whatever this device happens to have in its journey —
/// the account is the authority once it has one. That also makes this
/// idempotent: after the single write it fires the provider re-runs, finds the
/// gender in place, and does nothing ever again.
final Provider<void> genderSyncProvider = Provider<void>((Ref ref) {
  final AppUser? user = ref.watch(appUserProvider).valueOrNull;
  if (user == null || Gender.isValid(user.gender)) return;

  final String? answered = JourneyAnswers.decode(
    ref.watch(prefsProvider).journeyAnswers,
  ).gender;
  if (!Gender.isValid(answered)) return;

  // Fire-and-forget, and `saveGender` swallows its own failures: nothing on
  // screen is waiting for this, and the next app open would try again anyway.
  unawaited(ref.read(authRepositoryProvider).saveGender(answered));
});

/// Back-fills the days of a pause nobody was open to record.
///
/// Watched once from the app shell, like the other sync providers. Keyed to
/// [todayProvider] as well as the pause itself, so a phone left open across
/// midnight records the new day without being restarted.
final Provider<void> cycleCatchUpProvider = Provider<void>((Ref ref) {
  final Cycle cycle = ref.watch(cycleProvider);
  final DateTime today = ref.watch(todayProvider);
  if (!cycle.isActive) return;

  unawaited(
    ref
        .read(cycleRepositoryProvider)
        .catchUp(cycle: cycle, now: today)
        // Named for the write and not for what the write is. `debugPrint` is
        // not assert-guarded: it survives release builds into the iOS unified
        // log, which is readable over a cable and captured verbatim in the
        // sysdiagnose a user is asked to attach to a bug report. One Firestore
        // failure must not carry the most private state in the app out of the
        // two owner-only documents the whole data shape was chosen to keep it
        // inside.
        .catchError(
          (Object error) =>
              debugPrint('Layla Pro: day records not caught up ($error)'),
        ),
  );
});

final AutoDisposeAsyncNotifierProvider<CycleController, void>
cycleControllerProvider =
    AsyncNotifierProvider.autoDispose<CycleController, void>(
      CycleController.new,
    );

/// Starts and ends the pause for the screens. Like every other controller
/// here, it reports success rather than making the caller read it back off
/// `state`, and parks any failure there for a snackbar.
class CycleController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Begins a pause today.
  Future<bool> start() async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => ref.read(cycleRepositoryProvider).start(),
    );
    return !state.hasError;
  }

  /// Ends it, at her word and only at her word.
  Future<bool> end() async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => ref.read(cycleRepositoryProvider).end(),
    );
    return !state.hasError;
  }
}
