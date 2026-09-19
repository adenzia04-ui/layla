import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/journey_screen.dart';
import '../../features/prayer_lock/presentation/prayer_focus_screen.dart';
import '../../features/prayer_times/presentation/prayer_settings_screen.dart';
import '../../features/prayer_times/presentation/prayer_times_screen.dart';
import '../../features/profile/presentation/account_settings_screen.dart';
import '../../features/profile/presentation/notification_settings_screen.dart';
import '../../features/premium/presentation/paywall_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/widget_theme_screen.dart';
import '../../features/qibla/presentation/qibla_screen.dart';
import '../../features/mood/domain/mood_comfort.dart';
import '../../features/mood/presentation/mood_deck_screen.dart';
import '../../features/mood/presentation/mood_journal_screen.dart';
import '../../features/mood/presentation/saved_comforts_screen.dart';
import '../../features/mood/presentation/mood_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/stories/presentation/stories_screen.dart';
import '../../features/stories/presentation/story_composer_screen.dart';
import '../../features/stories/presentation/story_detail_screen.dart';
import '../../features/tahajjud/presentation/tahajjud_map_screen.dart';
import '../../features/tahajjud/presentation/tahajjud_screen.dart';
import '../../features/dua/presentation/tasbih_dua_home_screen.dart';
import 'widget_links.dart';
import '../../features/circles/presentation/circle_screen.dart';
import '../../features/friends/application/invite.dart'
    show pendingInviteProvider;
import '../../features/friends/presentation/friends_screen.dart';
import '../../features/soul/presentation/names_quiz_screen.dart';
import '../../features/soul/presentation/names_screen.dart';
import '../../features/tasbih/presentation/tasbih_screen.dart';
import '../../features/streaks/presentation/streak_screen.dart';
import '../../shell/app_shell.dart';
import 'invite_link.dart';
import 'tab_navigators.dart';
import 'routes.dart';

final GlobalKey<NavigatorState> _rootKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final AuthRepository auth = ref.watch(authRepositoryProvider);

  // A code arriving on a link is parked here for the Friends screen, which
  // prefills its field from it. The router only ever sets it.
  final InviteRouting invites = InviteRouting(
    remember: (String code) =>
        ref.read(pendingInviteProvider.notifier).state = code,
  );

  late final GoRouter router;

  /// An invite link's own redirect: the code is kept and the link becomes a
  /// destination. Shared by the path forms below; the scheme form, which
  /// go_router folds onto the splash, is caught in the top-level redirect.
  String inviteRedirect(BuildContext context, GoRouterState state) =>
      invites.onInvite(state.uri, cold: _startingUp(router));

  router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    // Rebuilds the redirect whenever the user signs in or out.
    refreshListenable: _StreamListenable<User?>(
      ref.watch(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (BuildContext context, GoRouterState state) {
      final String location = state.matchedLocation;

      // An invite link. The path forms have routes of their own below and
      // are let through to them. The scheme form, `layla://add?code=`, has
      // no path at all, and go_router folds it onto the splash route — so it
      // is read here, where its query still gives it away.
      if (IncomingInvite.matches(state.uri)) {
        if (location != Routes.splash) return null;
        return invites.onInvite(state.uri, cold: _startingUp(router));
      }

      // A tap on a home-screen widget. Same shape as the invite above: no
      // path, so go_router has folded it onto the splash and only the whole
      // uri still says where it meant to go.
      final String? fromWidget = widgetLinkTarget(state.uri);
      if (fromWidget != null) {
        if (_startingUp(router)) {
          // Cold start. The splash has to establish whether this person has
          // onboarded and whether they are signed in before anywhere is a
          // safe place to land, so the destination waits for it.
          ref.read(pendingWidgetLinkProvider.notifier).state = fromWidget;
          return null;
        }
        return fromWidget;
      }

      // The splash screen decides for itself where to go next.
      if (location == Routes.splash) return null;

      final bool signedIn = auth.currentUser != null;
      final bool isGuest = auth.currentUser?.isAnonymous ?? false;
      final bool isPublic = Routes.publicRoutes.contains(location);

      // Signed-out people land on the account screen, not the email form.
      // Email is one of three ways in now, and it is the one that asks the
      // most of someone who has not decided to stay yet.
      if (!signedIn) return isPublic ? null : Routes.welcome;
      // Signed in, the account screens are behind you — except sign-up for
      // a guest, which is their upgrade form: it links an email to the same
      // uid, so the streak comes along. Friends sends guests there.
      final bool upgrading = isGuest && location == Routes.signup;
      if (Routes.authRoutes.contains(location) && !upgrading) {
        return Routes.home;
      }

      // Nothing is pinned to the focus screen any more.
      //
      // This used to redirect every route back to /focus for the length of the
      // window, so an open prayer made the rest of Layla Pro unreachable. Two
      // rounds of narrowing it followed — first letting overdue sessions
      // through, because an unbounded session had locked people out of their
      // own settings. The honest end of that line is not to trap anyone at
      // all: the three choices live on the home screen, the banner carries
      // them everywhere else, and the OS shield goes on pausing the apps that
      // are actually meant to be paused.
      //
      // One thing is left to decide: whether an invite that opened the app
      // cold is still waiting. If so, this first arrival at home goes to
      // Friends instead, where the code is.
      return invites.onNavigation(location);
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
            const JourneyScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (BuildContext context, GoRouterState state) =>
            const WelcomeScreen(),
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

      // ── Invite links: never a screen, always a decision ──────────────
      GoRoute(path: Routes.addFriend, redirect: inviteRedirect),
      GoRoute(path: Routes.addFriendWeb, redirect: inviteRedirect),

      // ── Prayer focus: full screen, outside the shell, no bottom bar ──
      GoRoute(
        path: Routes.paywall,

        pageBuilder: (BuildContext context, GoRouterState state) =>
            _rise(state, const PaywallScreen()),
      ),
      GoRoute(
        path: '/focus/:prayer',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            PrayerFocusScreen(
              prayerKey: state.pathParameters['prayer'] ?? 'fajr',
            ),
      ),

      // ── The five-tab shell ────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: tabNavigatorKeys[0],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.home,
                builder: (BuildContext context, GoRouterState state) =>
                    const HomeScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'prayer-times',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const PrayerTimesScreen()),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'settings',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const PrayerSettingsScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'streak',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const StreakScreen()),
                  ),
                  GoRoute(
                    path: 'qibla',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const QiblaScreen()),
                  ),
                  GoRoute(
                    path: 'mood',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const MoodScreen()),
                    routes: <RouteBase>[
                      // Static paths first, or ':mood' would swallow them.
                      GoRoute(
                        path: 'saved',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const SavedComfortsScreen()),
                      ),
                      GoRoute(
                        path: 'journal',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const MoodJournalScreen()),
                      ),
                      GoRoute(
                        path: ':mood',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(
                                  state,
                                  MoodDeckScreen(
                                    mood:
                                        Mood.byName(
                                          state.pathParameters['mood'],
                                        ) ??
                                        Mood.hopeful,
                                  ),
                                ),
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'counter',
                            pageBuilder:
                                (BuildContext context, GoRouterState state) =>
                                    _rise(state, const TasbihScreen()),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const ProfileScreen()),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'widgets',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const WidgetThemeScreen()),
                      ),
                      GoRoute(
                        path: 'settings',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const AccountSettingsScreen()),
                        routes: <RouteBase>[
                          GoRoute(
                            path: 'notifications',
                            pageBuilder:
                                (BuildContext context, GoRouterState state) =>
                                    _rise(
                                      state,
                                      const NotificationSettingsScreen(),
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: tabNavigatorKeys[1],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.tahajjud,
                builder: (BuildContext context, GoRouterState state) =>
                    const TahajjudScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'map',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const TahajjudMapScreen()),
                  ),
                  GoRoute(
                    path: 'stories',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const StoriesScreen()),
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
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(
                                  state,
                                  StoryDetailScreen(
                                    storyId: state.pathParameters['id'] ?? '',
                                  ),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: tabNavigatorKeys[2],
            routes: <RouteBase>[
              GoRoute(
                path: Routes.tasbih,
                builder: (BuildContext context, GoRouterState state) =>
                    const TasbihDuaHomeScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'counter',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const TasbihScreen()),
                  ),
                  GoRoute(
                    path: 'names',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const NamesScreen()),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'quiz',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(state, const NamesQuizScreen()),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'friends',
                    pageBuilder: (BuildContext context, GoRouterState state) =>
                        _rise(state, const FriendsScreen()),
                    routes: <RouteBase>[
                      // A circle sits under Friends, so Back lands on the
                      // list it was opened from rather than on the hub.
                      GoRoute(
                        path: 'circles/:id',
                        pageBuilder:
                            (BuildContext context, GoRouterState state) =>
                                _rise(
                                  state,
                                  CircleScreen(
                                    circleId: state.pathParameters['id'] ?? '',
                                  ),
                                ),
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

  return router;
});

/// Whether the app has yet to get past the splash: nothing built, or the
/// splash still up.
///
/// A link that arrives then is a cold start as far as the invite goes,
/// whichever way the engine delivered it — as the initial route, or pushed
/// a moment after the first frame. Either way the splash's own `go(home)` is
/// still to come, and Friends has to be reached after it, not before.
bool _startingUp(GoRouter router) {
  final RouteMatchList current = router.routerDelegate.currentConfiguration;
  return current.isEmpty || current.uri.path == Routes.splash;
}

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
            Text(
              'That page does not exist:\n$location',
              textAlign: TextAlign.center,
            ),
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

/// The transition every pushed page uses: fade in while rising and settling
/// to full size.
///
/// Not the platform slide. Sliding in from the right says "the next page of
/// a document"; this says "here is something for you", and it was first
/// built for the mood deck — where it earned its keep — and then asked for
/// everywhere else. It applies only to pages you push from a tab, never to
/// switching between tabs, which is instant on purpose.
///
/// One trade: a custom transition gives up the iOS edge-swipe-to-go-back
/// gesture, which is wired to the Cupertino slide. The back button on every
/// one of these pages is the way out.
Page<void> _rise(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 460),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      child: child,
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
            Widget child,
          ) {
            final CurvedAnimation eased = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: eased,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(eased),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(eased),
                  child: child,
                ),
              ),
            );
          },
    );
