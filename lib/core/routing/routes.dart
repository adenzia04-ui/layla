/// Every path in the app, in one place, so no screen hard-codes a string.
abstract final class Routes {
  // Outside the shell — no bottom navigation.
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Shell branches.
  static const String home = '/home';
  static const String tahajjud = '/tahajjud';
  static const String qibla = '/qibla';
  static const String tasbih = '/tasbih';

  /// The counter itself, now one level in from the Tasbih + Dua hub.
  static const String tasbihCounter = '/tasbih/counter';
  static const String profile = '/profile';

  // Nested under Home.
  static const String prayerTimes = '/home/prayer-times';
  static const String prayerSettings = '/home/prayer-times/settings';
  static const String streak = '/home/streak';

  // Nested under Tahajjud.
  static const String tahajjudMap = '/tahajjud/map';
  static const String stories = '/tahajjud/stories';
  static const String storyCompose = '/tahajjud/stories/new';
  static String storyDetail(String id) => '/tahajjud/stories/$id';

  // Nested under Profile.
  static const String accountSettings = '/profile/settings';
  static const String notificationSettings = '/profile/settings/notifications';

  /// The prayer focus screen. Full-screen, no bottom bar, no back gesture.
  static String focus(String prayerKey) => '/focus/$prayerKey';
  static String focusConfirm(String prayerKey) => '/focus/$prayerKey/confirm';

  static const List<String> authRoutes = <String>[
    login,
    signup,
    forgotPassword,
  ];

  static const List<String> publicRoutes = <String>[
    splash,
    onboarding,
    login,
    signup,
    forgotPassword,
  ];
}
