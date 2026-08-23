import 'package:firebase_auth/firebase_auth.dart';

/// A user-presentable failure. Every repository converts platform exceptions
/// into one of these so the UI never has to read an error code.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  /// Translates the exceptions Noor actually encounters into plain language.
  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;

    if (error is FirebaseAuthException) {
      return AppFailure(_authMessage(error.code), code: error.code, cause: error);
    }
    if (error is FirebaseException) {
      final String message = switch (error.code) {
        'permission-denied' =>
          'You do not have permission to do that.',
        'unavailable' || 'network-request-failed' =>
          'No connection. Check your network and try again.',
        'unauthorized' => 'Sign in again to continue.',
        'canceled' => 'That was cancelled.',
        'quota-exceeded' => 'Storage limit reached. Try again later.',
        _ => error.message ?? 'Something went wrong. Please try again.',
      };
      return AppFailure(message, code: error.code, cause: error);
    }
    return AppFailure(
      'Something went wrong. Please try again.',
      cause: error,
    );
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'That email address does not look right.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        'email-already-in-use' =>
          'An account already exists with that email. Try logging in.',
        'weak-password' => 'Choose a password with at least 8 characters.',
        'too-many-requests' =>
          'Too many attempts. Please wait a moment and try again.',
        'network-request-failed' =>
          'No connection. Check your network and try again.',
        'requires-recent-login' =>
          'For security, please log in again before making this change.',
        'operation-not-allowed' =>
          'That sign-in method is not enabled for this app.',
        _ => 'We could not complete that. Please try again.',
      };

  @override
  String toString() => 'AppFailure($code): $message';
}
