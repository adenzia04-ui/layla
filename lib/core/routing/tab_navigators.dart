import 'package:flutter/widgets.dart';

/// One navigator per tab, so the shell can reach the stack a tab is sitting
/// on and take it back to that tab's first screen.
///
/// `goBranch(initialLocation: true)` resets only the routes the router itself
/// put there. Several screens — the whole Duas tree, for one — are opened
/// with `Navigator.push`, which the router knows nothing about, so tapping
/// Soul while three levels deep inside Duas did nothing at all, and the only
/// way out was the system back button, once per screen.
///
/// These live in a file of their own because both sides need them and the
/// router already imports the shell; putting them in either would make the
/// two files import each other.
final List<GlobalKey<NavigatorState>> tabNavigatorKeys =
    <GlobalKey<NavigatorState>>[
      GlobalKey<NavigatorState>(debugLabel: 'tab-home'),
      GlobalKey<NavigatorState>(debugLabel: 'tab-tahajjud'),
      GlobalKey<NavigatorState>(debugLabel: 'tab-soul'),
    ];
