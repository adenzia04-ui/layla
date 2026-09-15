import 'package:flutter/foundation.dart';

import '../../features/friends/domain/friend.dart';
import 'routes.dart';

/// The link that means "add this friend", in every shape it reaches the app.
///
/// `layla://add?code=ABC234` is the one the share sheet hands out. Parsed as
/// a URI its host is `add` and its path is empty — and on a cold start
/// go_router has already swapped that empty path for `/`, so by the time
/// the router sees it all that survives of the link is a `code` query on the
/// splash route. `/add?code=ABC234` is the plain path form, and
/// `/layla-pro/add.html?code=ABC234` is what a universal link from the launch
/// site would carry, should one ever be set up. All three land in the same
/// place.
abstract final class IncomingInvite {
  /// The custom scheme's host: the `add` in `layla://add`.
  static const String host = 'add';

  /// The query parameter the code travels in.
  static const String codeParameter = 'code';

  /// Whether [uri] is an invite link at all, whether or not it carries a code.
  static bool matches(Uri uri) {
    if (uri.host == host) return true;
    final String path = uri.path;
    if (path == Routes.addFriend || path == Routes.addFriendWeb) return true;
    // The custom scheme after go_router has folded its empty path onto the
    // splash route. Nothing else in the app puts a code on the splash.
    return path == Routes.splash &&
        uri.queryParameters.containsKey(codeParameter);
  }

  /// The code [uri] carries, or null for a link with none — or with
  /// something that could never be one.
  ///
  /// Only a whole, valid code is worth handing to the Friends screen: it
  /// prefills the field and asks "Add <name>?", and half a code has no name
  /// to look up. The same lenient reading as the field itself, so a link
  /// somebody has retyped by hand as "abc-234" still counts.
  static String? codeIn(Uri uri) {
    if (!matches(uri)) return null;
    final String code = FriendCode.normalize(
      uri.queryParameters[codeParameter] ?? '',
    );
    return FriendCode.isValid(code) ? code : null;
  }
}

/// Decides where an invite link sends the app, and keeps the one thing the
/// decision depends on afterwards: that a link opened the app cold.
///
/// Warm, a link goes straight to Friends. Cold — nothing drawn yet, or the
/// splash still up — it lets the splash play and route as it always has:
/// onboarding on a first run, the account screens for someone signed out,
/// home otherwise. Only that home is turned into Friends, once, where the
/// code is waiting.
///
/// Going straight to Friends from a cold start looked simpler and was worse.
/// Firebase is still restoring the session during the first frames, so the
/// sign-in gate read "signed out" and bounced the link to the welcome screen;
/// and a link that arrives while the splash is up would be undone four
/// seconds later, when the splash's own `go(home)` fired.
class InviteRouting {
  InviteRouting({required this.remember});

  /// Hands a code to whatever prefills the Friends screen.
  final ValueChanged<String> remember;

  /// A link opened the app cold, and Friends has not been shown for it yet.
  bool _coldInvite = false;

  /// A navigation to an invite link: remembers its code and says where to go.
  ///
  /// [cold] is whether the app has yet to get past the splash.
  String onInvite(Uri uri, {required bool cold}) {
    final String? code = IncomingInvite.codeIn(uri);
    if (code != null) remember(code);
    if (!cold) return Routes.friends;
    _coldInvite = code != null;
    return Routes.splash;
  }

  /// Any other navigation: the first one to reach home after a cold invite
  /// goes to Friends instead. Null leaves the navigation alone.
  String? onNavigation(String location) {
    if (!_coldInvite || location != Routes.home) return null;
    _coldInvite = false;
    return Routes.friends;
  }
}
