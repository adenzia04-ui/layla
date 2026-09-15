/// Every path in the app, in one place, so no screen hard-codes a string.
abstract final class Routes {
  // Outside the shell — no bottom navigation.
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // Shell branches.
  static const String home = '/home';
  static const String tahajjud = '/tahajjud';
  static const String tasbih = '/tasbih';

  /// The counter itself, now one level in from the Tasbih + Dua hub.
  static const String tasbihCounter = '/tasbih/counter';

  /// The Ninety-Nine Names, one a day.
  static const String soulNames = '/tasbih/names';
  static const String soulNamesQuiz = '/tasbih/names/quiz';

  /// The people who can see your prayers, and whose you can see.
  static const String friends = '/tasbih/friends';

  /// A circle: a few friends keeping one goal for forty days.
  static String circle(String id) => '/tasbih/friends/circles/$id';

  /// An invite link, `layla://add?code=ABC234`. Never a screen: the router
  /// reads the code off it and sends the person on to Friends, where the
  /// field is already filled in. See `IncomingInvite` for the shapes it takes.
  static const String addFriend = '/add';

  /// The launch site's invite page, as a universal link would present it.
  /// iOS is not set up to open those yet; the route is here so the link
  /// lands in the same place the day it is.
  static const String addFriendWeb = '/layla-pro/add.html';

  // Nested under Home.
  /// Profile, reached from the Home header under the settings gear rather
  /// than from the tab bar.
  static const String profile = '/home/profile';
  static const String prayerTimes = '/home/prayer-times';
  static const String prayerSettings = '/home/prayer-times/settings';
  static const String streak = '/home/streak';

  /// Qibla, reached from the Home feature rail rather than the tab bar.
  ///
  /// It answers one question and you leave — which is a page you visit, not a
  /// place you live. A tab implies somewhere you return to and keeps state
  /// waiting for you; the compass has no state worth keeping.
  static const String qibla = '/home/qibla';

  /// "How are you feeling?" — a verse or hadith for the mood you name.
  static const String mood = '/home/mood';

  /// The deck for one mood — one card at a time, turned over by tapping.
  static String moodDeck(String mood) => '/home/mood/$mood';

  /// Passages someone has kept, and lines they have written afterwards.
  /// Both stay on the phone.
  static const String moodSaved = '/home/mood/saved';
  static const String moodJournal = '/home/mood/journal';

  /// The tasbih counter, reached from a deck's "one small step".
  ///
  /// Nested under the mood rather than pushed from the Tasbih tab: a push
  /// across tabs switched tabs, and Back then led to the Tasbih hub, not to
  /// the deck the person had been reading.
  static String moodCounter(String mood) => '/home/mood/$mood/counter';

  // Nested under Tahajjud.
  static const String tahajjudMap = '/tahajjud/map';
  static const String stories = '/tahajjud/stories';
  static const String storyCompose = '/tahajjud/stories/new';
  static String storyDetail(String id) => '/tahajjud/stories/$id';

  // Nested under Profile.
  static const String accountSettings = '/home/profile/settings';
  static const String widgetTheme = '/home/profile/widgets';
  static const String notificationSettings =
      '/home/profile/settings/notifications';

  /// Layla Pro Premium — the paywall, over everything.
  static const String paywall = '/paywall';

  /// The prayer focus screen. Full-screen, no bottom bar, no back gesture.
  static String focus(String prayerKey) => '/focus/$prayerKey';

  static const List<String> authRoutes = <String>[
    welcome,
    login,
    signup,
    forgotPassword,
  ];

  static const List<String> publicRoutes = <String>[
    splash,
    onboarding,
    welcome,
    login,
    signup,
    forgotPassword,
  ];
}
