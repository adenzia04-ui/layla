import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` once SharedPreferences has been loaded, so the rest
/// of the app can read it synchronously.
final Provider<SharedPreferences> sharedPrefsProvider =
    Provider<SharedPreferences>(
      (Ref ref) =>
          throw UnimplementedError('sharedPrefsProvider must be overridden'),
    );

final Provider<PrefsService> prefsProvider = Provider<PrefsService>(
  (Ref ref) => PrefsService(ref.watch(sharedPrefsProvider)),
);

/// Small typed façade over SharedPreferences. Everything that survives an app
/// restart but does not belong in Firestore lives here.
class PrefsService {
  const PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static const String _kOnboarded = 'onboarding_complete';
  static const String _kLat = 'last_lat';
  static const String _kLng = 'last_lng';
  static const String _kCity = 'last_city';
  static const String _kCountry = 'last_country';
  static const String _kLocationAt = 'last_location_at';
  static const String _kUse24h = 'use_24h_clock';
  static const String _kTasbihCount = 'tasbih_count';
  static const String _kTasbihTarget = 'tasbih_target';
  static const String _kTasbihDhikr = 'tasbih_dhikr';
  static const String _kTasbihMode = 'tasbih_mode';
  static const String _kTasbihStage = 'tasbih_stage';
  static const String _kTasbihRoutine = 'tasbih_routine';
  static const String _kStarredDuas = 'starred_duas';
  static const String _kTasbihStyle = 'tasbih_style';
  static const String _kActiveSession = 'active_prayer_session';
  static const String _kAppBlocking = 'app_blocking_enabled';
  static const String _kJourney = 'journey_answers';
  static const String _kAskedNotifications = 'asked_notifications';

  bool get onboardingComplete => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboardingComplete(bool value) =>
      _prefs.setBool(_kOnboarded, value);

  /// The first-run questionnaire, as one JSON blob.
  ///
  /// One key rather than a dozen typed pairs. The answers are only ever read
  /// and written together, none of them is queried on its own, and a shape
  /// that will keep growing as the journey gains steps should not mean a new
  /// getter, setter and key every time.
  String get journeyAnswers => _prefs.getString(_kJourney) ?? '';
  Future<void> setJourneyAnswers(String value) =>
      _prefs.setString(_kJourney, value);

  /// Whether iOS has been asked for notification permission.
  ///
  /// Tracked rather than re-queried, because the system prompt only ever
  /// appears once per install: asking a second time does nothing at all and
  /// returns the previous answer, so the app has to remember whether it has
  /// spent that one chance.
  bool get askedNotifications => _prefs.getBool(_kAskedNotifications) ?? false;
  Future<void> setAskedNotifications(bool v) =>
      _prefs.setBool(_kAskedNotifications, v);

  bool get use24hClock => _prefs.getBool(_kUse24h) ?? false;
  Future<void> setUse24hClock(bool value) => _prefs.setBool(_kUse24h, value);

  /// Whether the user opted into the native lock — the Android soft lock or
  /// the iOS Screen Time shield, depending on the device. Off by default on
  /// both: it costs permissions the user must grant deliberately.
  bool get appBlockingEnabled => _prefs.getBool(_kAppBlocking) ?? false;
  Future<void> setAppBlockingEnabled(bool value) =>
      _prefs.setBool(_kAppBlocking, value);

  // ── Cached location so the dashboard can render before the GPS replies ──
  ({double lat, double lng, String city, String country, DateTime at})?
  get cachedLocation {
    final double? lat = _prefs.getDouble(_kLat);
    final double? lng = _prefs.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return (
      lat: lat,
      lng: lng,
      city: _prefs.getString(_kCity) ?? '',
      country: _prefs.getString(_kCountry) ?? '',
      at: DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_kLocationAt) ?? 0),
    );
  }

  Future<void> cacheLocation({
    required double lat,
    required double lng,
    String city = '',
    String country = '',
  }) async {
    await _prefs.setDouble(_kLat, lat);
    await _prefs.setDouble(_kLng, lng);
    await _prefs.setString(_kCity, city);
    await _prefs.setString(_kCountry, country);
    await _prefs.setInt(_kLocationAt, DateTime.now().millisecondsSinceEpoch);
  }

  // ── Tasbih survives restarts locally; Firestore only gets finished sets ──
  int get tasbihCount => _prefs.getInt(_kTasbihCount) ?? 0;
  Future<void> setTasbihCount(int value) => _prefs.setInt(_kTasbihCount, value);

  int get tasbihTarget => _prefs.getInt(_kTasbihTarget) ?? 33;
  Future<void> setTasbihTarget(int value) =>
      _prefs.setInt(_kTasbihTarget, value);

  String get tasbihDhikr => _prefs.getString(_kTasbihDhikr) ?? 'SubhanAllah';
  Future<void> setTasbihDhikr(String value) =>
      _prefs.setString(_kTasbihDhikr, value);

  /// 'manual' or 'sunnah'. Stored as a name rather than an index so that
  /// reordering the enum cannot silently reinterpret someone's saved mode.
  String get tasbihMode => _prefs.getString(_kTasbihMode) ?? 'manual';
  Future<void> setTasbihMode(String value) =>
      _prefs.setString(_kTasbihMode, value);

  /// How far through the after-prayer sequence, 0–2. Only meaningful in
  /// Sunnah mode.
  int get tasbihStage => _prefs.getInt(_kTasbihStage) ?? 0;
  Future<void> setTasbihStage(int value) => _prefs.setInt(_kTasbihStage, value);

  /// Which sunnah is being counted, by its stable id.
  String get tasbihRoutine =>
      _prefs.getString(_kTasbihRoutine) ?? 'after_prayer';
  Future<void> setTasbihRoutine(String value) =>
      _prefs.setString(_kTasbihRoutine, value);

  // ── Starred duas, by the book's own number ────────────────────────────────
  //
  // Stored as strings because SharedPreferences has no int list. Anything
  // unparseable is dropped rather than throwing: a corrupt entry should cost
  // one star, not the whole list.
  Set<int> get starredDuas =>
      (_prefs.getStringList(_kStarredDuas) ?? <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  /// Which counter face the tasbih shows, by its enum name.
  String get tasbihStyle => _prefs.getString(_kTasbihStyle) ?? 'ring';
  Future<void> setTasbihStyle(String value) =>
      _prefs.setString(_kTasbihStyle, value);

  Future<void> setStarredDuas(Set<int> value) => _prefs.setStringList(
    _kStarredDuas,
    value.map((int n) => n.toString()).toList(),
  );

  /// The unconfirmed prayer that must re-open the focus screen on next launch.
  /// Format: "2026-08-20|fajr|<endMillis>".
  String? get activeSession => _prefs.getString(_kActiveSession);
  Future<void> setActiveSession(String? value) async {
    if (value == null) {
      await _prefs.remove(_kActiveSession);
    } else {
      await _prefs.setString(_kActiveSession, value);
    }
  }
}
