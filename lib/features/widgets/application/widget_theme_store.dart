import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/prefs_service.dart';
import '../domain/widget_theme.dart';

/// The colour set the widgets draw in. Local to the phone: it is a matter of
/// how this home screen looks, not of the account.
final NotifierProvider<WidgetThemeStore, WidgetTheme> widgetThemeProvider =
    NotifierProvider<WidgetThemeStore, WidgetTheme>(WidgetThemeStore.new);

class WidgetThemeStore extends Notifier<WidgetTheme> {
  static const String _key = 'widget_theme';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  WidgetTheme build() => WidgetTheme.byId(_prefs.getString(_key));

  /// The snapshot provider watches this, so a change republishes to the App
  /// Group and redraws every widget on its own.
  Future<void> set(WidgetTheme theme) async {
    if (theme == state) return;
    state = theme;
    await _prefs.setString(_key, theme.id);
  }
}
