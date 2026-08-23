/// Endpoints Layla talks to that are not Firebase.
class AppConfig {
  const AppConfig._();

  /// The Cloudflare Worker that sends the welcome email.
  ///
  /// Empty until `wrangler deploy` has been run — see `worker/README.md`. While
  /// it is empty the app simply does not attempt to send, so sign-up works
  /// exactly as before.
  static const String welcomeEmailEndpoint = String.fromEnvironment(
    'LAYLA_WELCOME_ENDPOINT',
    defaultValue: '',
  );

  static bool get canSendWelcomeEmail => welcomeEmailEndpoint.isNotEmpty;
}
