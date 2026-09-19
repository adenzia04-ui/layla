import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';

/// Where a `layla://` link from a home-screen widget actually goes.
///
/// The widgets have carried these links since the iPhone ones were written,
/// and until now not one of them arrived anywhere. `layla://qibla` has no
/// path — only a scheme and a host — so go_router folds it onto the splash
/// route, the splash then does what it always does, and the tap reads as
/// "opens the app" rather than "opens the compass". Nothing logged it,
/// because nothing had gone wrong: the link was simply never claimed.
///
/// Every id here is one the widgets on both platforms already send, so this
/// is the one place they are turned into destinations, and adding a widget
/// link means adding it here as well or it silently does nothing.
///
/// Returns null for anything that is not one of ours — including the invite
/// link, which has its own handling and must not be caught here.
String? widgetLinkTarget(Uri uri) {
  if (uri.scheme != 'layla') return null;

  // `layla://duas/morning` parses as host `duas`, path `/morning`; the
  // website's own links arrive as paths on https, and those are not ours.
  final String head = uri.host;

  return switch (head) {
    'pray' => Routes.home,
    'qibla' => Routes.qibla,
    'tasbih' => Routes.tasbihCounter,
    'names' => Routes.soulNames,

    // The verse widget offers a line for how you feel, which is what the
    // Mood decks are; there is no screen that is only a verse.
    'verse' => Routes.mood,

    // There is no route to the dua library at all — the Soul tab opens it
    // with a bare MaterialPageRoute — so `morning` and `praise` cannot be
    // honoured as written. Soul is where all three doors are visible and one
    // tap away, which is the nearest true answer rather than a guess that
    // lands somewhere unrelated.
    'duas' => Routes.tasbih,

    _ => null,
  };
}

/// A widget link that arrived while the app was still starting up.
///
/// A cold start cannot simply be redirected: the splash is what decides
/// whether this person has onboarded and whether they are signed in, and
/// jumping over it lands somebody who has never opened the app on the Qibla
/// compass. So the destination waits here and the splash spends it once it
/// knows those two things.
final StateProvider<String?> pendingWidgetLinkProvider =
    StateProvider<String?>((Ref ref) => null);
