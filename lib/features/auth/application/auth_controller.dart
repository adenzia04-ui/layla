import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../../onboarding/domain/journey_answers.dart';
import '../data/auth_repository.dart';

final AutoDisposeAsyncNotifierProvider<AuthController, void>
authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);

/// Drives every auth form. Screens watch `isLoading` for the button spinner
/// and listen for `error` to show a snackbar — they never touch Firebase.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  /// Whether this notifier has been thrown away while a sign-in was still
  /// running.
  ///
  /// It is auto-dispose, and every screen that uses it navigates away the
  /// instant the call succeeds — so by the time [_run] comes back from the
  /// network, the notifier it wants to write to is frequently already gone.
  bool _gone = false;

  @override
  FutureOr<void> build() {
    _gone = false;
    ref.onDispose(() => _gone = true);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _signIn(() => _repo.signIn(email: email, password: password));

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _signIn(() => _repo.signUp(name: name, email: email, password: password));

  /// The name the onboarding journey already asked for.
  ///
  /// "What should I call you?" is the first question the app asks, and the
  /// answer was being used only to word the pledge and the reflection steps —
  /// then thrown away. When a provider gives no name, this is the one the
  /// person already typed, so asking again would be asking twice.
  String get _journeyName =>
      JourneyAnswers.decode(ref.read(prefsProvider).journeyAnswers).name.trim();

  Future<bool> signInWithApple() =>
      _signIn(() => _repo.signInWithApple(fallbackName: _journeyName));

  Future<bool> signInWithGoogle() =>
      _signIn(() => _repo.signInWithGoogle(fallbackName: _journeyName));

  Future<bool> continueAsGuest() =>
      _signIn(() => _repo.continueAsGuest(fallbackName: _journeyName));

  Future<bool> upgradeGuest({
    required String name,
    required String email,
    required String password,
  }) => _signIn(
    () => _repo.upgradeGuest(name: name, email: email, password: password),
  );

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> signOut() => _run(() async {
    final PrefsService prefs = ref.read(prefsProvider);
    // The pending prayer session belongs to the person who was signed in.
    await prefs.setActiveSession(null);

    // So does the intro.
    //
    // `onboarding_complete` and the journey answers are stored per device,
    // not per account, and nothing used to clear them. Two consequences,
    // both wrong: signing out and back in skipped the intro entirely, and
    // — worse — the next person to sign in on this phone inherited the
    // previous person's answers about their own prayer habits.
    await prefs.setOnboardingComplete(false);
    await prefs.setJourneyAnswers('');

    await _repo.signOut();
  });

  Future<bool> deleteAccount() => _run(_repo.deleteAccount);

  /// [_run], plus the one onboarding answer that has to outlive this device.
  ///
  /// The gender question is asked before there is an account to write it to,
  /// so the answer sat in SharedPreferences alone — and [signOut] clears that.
  /// Answering "sister" once therefore did not survive signing out and back
  /// in, and with it went the only thing that decides whether the prayer pause
  /// is ever offered, with nothing on screen to explain where it had gone.
  /// Every way into an account comes through here, because every one of them
  /// is the first moment there is a document to write it to.
  ///
  /// The write is never allowed to fail the sign-in. It is fire-and-forget and
  /// [AuthRepository.saveGender] swallows its own errors: somebody who is
  /// signed in but whose profile did not take the answer is picked up by
  /// `genderSyncProvider` on the next app open, whereas an exception raised
  /// here would leave them outside their account over a field.
  Future<bool> _signIn(Future<void> Function() action) async {
    // Read before the await, not after. This notifier is auto-dispose and
    // every screen navigates away the instant the call succeeds, so `ref` is
    // frequently dead by the time the network comes back.
    final String? answered = JourneyAnswers.decode(
      ref.read(prefsProvider).journeyAnswers,
    ).gender;
    final AuthRepository repo = _repo;

    final bool ok = await _run(action);
    if (ok) unawaited(repo.saveGender(answered));
    return ok;
  }

  /// Runs [action], parks any failure in `state`, and reports success so the
  /// caller can navigate only when it actually worked.
  ///
  /// The result is returned rather than read back off `state`, because by then
  /// there may be no `state` to read. Assigning to a disposed notifier throws
  /// "Bad state: Future already completed" — an unhandled async error with a
  /// stack trace pointing at Riverpod internals, which says nothing about the
  /// sign-in that actually caused it.
  Future<bool> _run(Future<void> Function() action) async {
    if (_gone) return false;
    state = const AsyncValue<void>.loading();

    final AsyncValue<void> result = await AsyncValue.guard(action);
    // The screen navigated away and took the notifier with it. The work itself
    // still finished, so report honestly on it and write nothing.
    if (_gone) return !result.hasError;

    state = result;
    return !result.hasError;
  }
}
