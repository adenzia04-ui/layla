/// Endpoints Layla Pro talks to that are not Firebase.
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

  /// The Cloudflare Worker that asks Claude to judge a prayer-mat photo.
  ///
  /// Empty until `wrangler deploy` has been run — see `worker/MAT_CHECK.md`.
  /// While it is empty the app never calls out and the on-device check decides
  /// on its own, which is exactly how it behaves today.
  static const String matCheckEndpoint = String.fromEnvironment(
    'LAYLA_MAT_ENDPOINT',
    defaultValue: '',
  );

  static bool get canAskClaudeAboutMat => matCheckEndpoint.isNotEmpty;
}
