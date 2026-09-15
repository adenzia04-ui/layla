import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/friend.dart';

/// A friend code that arrived by link and is waiting for the Friends screen.
///
/// The router puts it here when the app is opened from an invite link; the
/// screen prefills the code field from it, asks "Add <name>?", and clears it.
/// A provider rather than a route parameter because the app may have to sign
/// the person in — or finish onboarding — before the screen exists, and the
/// code has to survive that.
final StateProvider<String?> pendingInviteProvider = StateProvider<String?>(
  (Ref ref) => null,
);

/// The link a person sends instead of reading a code aloud.
///
/// A page on the launch site rather than a bare custom-scheme URL: a
/// `layla://` link is dead in a chat on a phone without the app, whereas the
/// page can show the code, point at the App Store and open the app when it
/// is there. The app also accepts `layla://add?code=` directly, which is what
/// the page hands over.
abstract final class InviteLink {
  static const String host = 'adenzia04-ui.github.io';
  static const String path = '/layla-pro/add.html';
  static const String page = 'https://$host$path';

  /// The custom scheme in ios/Runner/Info.plist.
  static const String scheme = 'layla';

  static const String param = 'code';

  /// "https://adenzia04-ui.github.io/layla-pro/add.html?code=ABC234"
  static String forCode(String code) =>
      '$page?$param=${FriendCode.normalize(code)}';

  /// What lands in the other person's messages.
  static String shareText(String code) =>
      'Add me on Layla Pro: ${forCode(code)}';

  /// The code an incoming link carries, or null when [uri] is not an invite
  /// — any other link into the app, or an invite whose code is not one this
  /// app could have made. Lenient about the code itself the way the field
  /// is: lowercase and a hyphen are fine.
  static String? codeFrom(Uri uri) {
    final bool page =
        uri.scheme == 'https' && uri.host == host && uri.path == path;
    final bool app =
        uri.scheme == scheme &&
        (uri.host == 'add' || uri.path == '/add' || uri.path == 'add');
    if (!page && !app) return null;
    final String code = FriendCode.normalize(uri.queryParameters[param] ?? '');
    return FriendCode.isValid(code) ? code : null;
  }
}

/// "https://adenzia04-ui.github.io/layla-pro/add.html?code=ABC234"
String inviteLinkFor(String code) => InviteLink.forCode(code);

/// "Add me on Layla Pro: <link>" — the share text.
String inviteShareText(String code) => InviteLink.shareText(code);
