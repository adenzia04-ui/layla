import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../data/auth_repository.dart';

final AutoDisposeAsyncNotifierProvider<AuthController, void>
    authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(
  AuthController.new,
);

/// Drives every auth form. Screens watch `isLoading` for the button spinner
/// and listen for `error` to show a snackbar — they never touch Firebase.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({
    required String email,
    required String password,
  }) =>
      _run(() => _repo.signIn(email: email, password: password));

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(() => _repo.signUp(name: name, email: email, password: password));

  Future<bool> continueAsGuest() => _run(_repo.continueAsGuest);

  Future<bool> upgradeGuest({
    required String name,
    required String email,
    required String password,
  }) =>
      _run(
        () => _repo.upgradeGuest(name: name, email: email, password: password),
      );

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<bool> signOut() => _run(() async {
        // The pending prayer session belongs to the person who was signed in.
        await ref.read(prefsProvider).setActiveSession(null);
        await _repo.signOut();
      });

  Future<bool> deleteAccount() => _run(_repo.deleteAccount);

  /// Runs [action], parks any failure in `state`, and reports success so the
  /// caller can navigate only when it actually worked.
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}
