import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/services/prefs_service.dart';

/// Asks iOS for permission to send reminders, once, on the first run that
/// reaches the app proper.
///
/// Nothing did this. `DarwinInitializationSettings` deliberately sets
/// `requestAlertPermission: false` — the plan was to ask "explicitly after
/// onboarding" — but the only things that ever asked were the two test
/// buttons buried in settings and the onboarding step added later. An account
/// that predated that step, or anyone who never pressed a test button, had
/// simply never been asked, so no reminder could arrive and nothing said why.
///
/// The flag is stored rather than the permission re-queried, because iOS shows
/// its prompt exactly once per install. A refusal is final until the person
/// changes it in Settings, and asking again is a no-op — so this must not
/// mistake "asked and declined" for "not yet asked" and go quiet forever.
final Provider<void> notificationPermissionProvider = Provider<void>((Ref ref) {
  final PrefsService prefs = ref.watch(prefsProvider);
  if (prefs.askedNotifications) return;

  Future<void>(() async {
    // Marked before the await, not after: the prompt is modal and the request
    // can be left hanging while someone thinks about it, and a rebuild in that
    // window would otherwise queue a second ask.
    await prefs.setAskedNotifications(true);
    await ref.read(notificationServiceProvider).requestPermissions();
  });
});
