import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/prayer_lock/application/prayer_lock_controller.dart';
import '../../features/prayer_lock/domain/prayer_session.dart';
import '../../features/prayer_lock/presentation/prayer_confirmation_screen.dart';
import '../../features/prayer_lock/presentation/prayer_focus_screen.dart';
import '../../features/prayer_times/presentation/prayer_settings_screen.dart';
import '../../features/prayer_times/presentation/prayer_times_screen.dart';
import '../../features/profile/presentation/account_settings_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/qibla/presentation/qibla_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/stories/presentation/stories_screen.dart';
import '../../features/stories/presentation/story_composer_screen.dart';
import '../../features/stories/presentation/story_detail_screen.dart';
import '../../features/tahajjud/presentation/tahajjud_map_screen.dart';
import '../../features/tahajjud/presentation/tahajjud_screen.dart';
import '../../features/dua/presentation/tasbih_dua_home_screen.dart';
import '../../features/tasbih/presentation/tasbih_screen.dart';
import '../../features/streaks/presentation/streak_screen.dart';
import '../../shell/app_shell.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> _rootKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final AuthRepository auth = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    // Rebuilds the redirect whenever the user signs in or out.
    refreshListenable: _StreamListenable<User?>(
      ref.watch(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;

      // The splash screen decides for itself where to go next.
      if (location == Routes.splash) return null;

      final bool signedIn = auth.currentUser != null;
      final bool isPublic = Routes.publicRoutes.contains(location);

      if (!signedIn) return isPublic ? null : Routes.login;
      if (Routes.authRoutes.contains(location)) return Routes.home;

      // An unconfirmed prayer holds the user on the focus flow. This is the
      // in-app half of the prayer lock: leaving Noor is possible, but every
      // route inside it leads back here until the two steps are done.
      // Hold the user on the focus screen for the length of the prayer
      // window — but only that long.
      //
      // Sessions now outlive their window (apps stay blocked until confirmed),
      // and pinning the router to /focus for an unbounded session locked the
      // user inside one screen of Noor with no route to Profile, and therefore
      // no way to turn the feature off. Blocking *other* apps is the feature;
      // blocking Noor itself was a bug.
      //
      // Once overdue, the persistent banner keeps confirmation one tap away
      // and the OS shield keeps the other apps paused.
      final PrayerSession? session = ref.read(activeSessionProvider);
      if (session != null &&
          !session.isOverdueAt(DateTime.now()) &&
          !location.startsWith('/focus')) {
        return Routes.focus(session.prayer.key);
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: Routes.signup,
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),

      // ── Prayer focus: full screen, outside the shell, no bottom bar ──
      GoRoute(
        path: '/focus/:prayer',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            PrayerFocusScreen(
          prayerKey: state.pathParameters['prayer'] ?? 'fajr',
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'confirm',
            parentNavigatorKey: _rootKey,
            builder: (BuildContext context, GoRouterState state) =>
                PrayerConfirmationScreen(
              prayerKey: state.pathParameters['prayer'] ?? 'fajr',
            ),
          ),
        ],
      ),

      // ── The five-tab shell ────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'prayer-times',
                    builder: (BuildContext context, GoRouterState state) =>
                        const PrayerTimesScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'settings',
                        builder: (BuildContext context, GoRouterState state) =>
                            const PrayerSettingsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'streak',
                    builder: (BuildContext context, GoRouterState state) =>
                        const StreakScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.tahajjud,
                builder: (BuildContext context, GoRouterState state) =>
                    const TahajjudScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'map',
                    builder: (BuildContext context, GoRouterState state) =>
                        const TahajjudMapScreen(),
                  ),
                  GoRoute(
                    path: 'stories',
                    builder: (BuildContext context, GoRouterState state) =>
                        const StoriesScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'new',
                        // Above the shell, so the composer owns the whole
                        // screen. Inside it, the tab bar sat on top of the
                        // Share button and every attempt to make room for one
                        // put a gap under the other. Writing a story is a
                        // task you finish and leave, not a tab.
                        parentNavigatorKey: _rootKey,
                        builder: (BuildContext context, GoRouterState state) =>
                            const StoryComposerScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (BuildContext context, GoRouterState state) =>
                            StoryDetailScreen(
                          storyId: state.pathParameters['id'] ?? '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.qibla,
                builder: (BuildContext context, GoRouterState state) =>
                    const QiblaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.tasbih,
                builder: (BuildContext context, GoRouterState state) =>
                    const TasbihDuaHomeScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'counter',
                    builder: (BuildContext context, GoRouterState state) =>
                        const TasbihScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.profile,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'settings',
                    builder: (BuildContext context, GoRouterState state) =>
                        const AccountSettingsScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'notifications',
                        builder: (BuildContext context, GoRouterState state) =>
                            const NotificationSettingsScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        _RouteNotFound(location: state.uri.toString()),
  );
});

/// Bridges a stream into the `Listenable` GoRouter wants for `refreshListenable`.
class _StreamListenable<T> extends ChangeNotifier {
  _StreamListenable(Stream<T> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<T> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.explore_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text('That page does not exist:\n$location',
                    textAlign: TextAlign.center,),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(Routes.home),
                  child: const Text('Go home'),
                ),
              ],
            ),
          ),
        ),
      );
}
