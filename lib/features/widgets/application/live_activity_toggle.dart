import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/prefs_service.dart';

/// Whether the prayer Live Activity is shown at all.
///
/// It sits on the Lock Screen and in the Dynamic Island with a countdown that
/// ticks every second, and that ticking is not free. On by default; a person
/// who would rather keep the battery turns it off here, and the activity is
/// ended on the spot rather than left to expire.
final NotifierProvider<LiveActivityToggle, bool> liveActivityEnabledProvider =
    NotifierProvider<LiveActivityToggle, bool>(LiveActivityToggle.new);

class LiveActivityToggle extends Notifier<bool> {
  static const String _key = 'live_activity_enabled';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  bool build() => _prefs.getBool(_key) ?? true;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await _prefs.setBool(_key, enabled);
  }
}
