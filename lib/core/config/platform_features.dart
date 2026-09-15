import 'dart:io';

/// What the phone underneath can actually do.
///
/// Layla Pro ships on iPhone and on Android from the same Dart, and three
/// features exist on only one of them. A screen that offers a switch the
/// platform cannot honour is worse than a screen that never mentions it: the
/// switch flips, nothing happens, and the app looks broken rather than
/// honest. So every place that shows one of these asks here first.
///
/// Tests run on the Dart VM, where `Platform` is neither iOS nor Android.
/// Everything below is therefore false there, which is the safe answer —
/// a widget test never renders a promise that only one platform keeps.
abstract final class Have {
  const Have._();

  /// WidgetKit home-screen and Lock Screen widgets, and the colour sets they
  /// draw in. Android app widgets are a separate piece of native work that
  /// does not exist yet; until it does, the whole "Widgets & colours" screen
  /// has nothing to configure.
  static bool get homeScreenWidgets => Platform.isIOS;

  /// The Lock Screen / Dynamic Island countdown. Android's nearest relative
  /// is an ongoing notification, which is not the same thing and is not
  /// built.
  static bool get liveActivity => Platform.isIOS;

  /// A shield the operating system enforces, as opposed to Android's
  /// best-effort return-to-the-app nudge. The difference is large enough that
  /// the wording around the prayer lock changes with it — see
  /// `docs/PRAYER_LOCK_LIMITATIONS.md`.
  static bool get enforcedAppLock => Platform.isIOS;
}
