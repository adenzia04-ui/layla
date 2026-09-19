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

  /// Home-screen widgets. Both platforms have them now: WidgetKit on iPhone,
  /// app widgets on Android. They are not the same set — Android has the next
  /// prayer and the day's times, where iOS also has the globe, the tracker
  /// and the Lock Screen — but on both there is something to configure.
  static bool get homeScreenWidgets => Platform.isIOS || Platform.isAndroid;

  /// The colour sets. Both platforms honour them now: the nine palettes are
  /// generated for Android straight from the iOS table, so a stone tapped on
  /// either phone draws the same widget.
  static bool get widgetColourSets => homeScreenWidgets;

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
