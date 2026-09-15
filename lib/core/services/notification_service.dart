import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Payloads are `noor://focus/<prayerId>` so a tap can route straight into the
/// prayer focus screen.
typedef NotificationTapHandler = void Function(String payload);

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) => NotificationService.instance);

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationTapHandler? _onTap;
  bool _ready = false;

  // Channel ids — keep in sync with android/app/src/main/AndroidManifest.xml.
  // The `_adhan` suffix is not decoration. Android freezes a channel's sound
  // when the channel is created and ignores every later change, so adding the
  // adhan meant retiring the old ids — an existing install would otherwise
  // keep playing the default tone forever.
  static const String _reminderChannel = 'prayer_reminders_adhan';
  static const String _focusChannel = 'prayer_focus_adhan';
  static const String _tahajjudChannel = 'tahajjud_adhan';

  /// A short, verified line for each prayer, shown instead of the generic
  /// "tap to start" body.
  ///
  /// Every one is a Qur'anic verse or an authenticated hadith with its
  /// reference, checked against sunnah.com rather than written from memory —
  /// an unsourced saying attributed to the Prophet ﷺ in a notification is
  /// exactly the kind of thing that should not be invented for flavour.
  static const Map<String, String> _prayerWords = <String, String>{
    'fajr':
        'The two rak‘ahs before Fajr are better than the world and all '
        'it contains. — Muslim 725',
    'dhuhr':
        'Indeed, prayer has been decreed upon the believers a decree of '
        'specified times. — Qur’an 4:103',
    'asr':
        'Whoever prays the two cool prayers — ‘Asr and Fajr — will enter '
        'Paradise. — Bukhari 574',
    'maghrib':
        'And establish prayer at the two ends of the day and at the '
        'approach of the night. — Qur’an 11:114',
    'isha':
        'Whoever prays ‘Isha in congregation, it is as if he prayed half '
        'the night. — Muslim 656',
    'tahajjud':
        'The best prayer after the prescribed prayers is the prayer '
        'of the night. — Muslim 1163',
  };

  /// The call to prayer, played instead of the system tone.
  ///
  /// iOS wants a filename in the app bundle; Android wants a bare resource
  /// name from `res/raw`. The clip is 17s — iOS silently falls back to the
  /// default tone for anything over 30s, so it must stay short.
  /// The file iOS plays for prayer reminders. The adhan by default; the
  /// person can choose a quieter tone in Reminders settings, and the choice
  /// is applied here before anything is scheduled. See NotificationSounds.
  static String iosSound = 'adhan.caf';
  static const RawResourceAndroidNotificationSound _adhanAndroid =
      RawResourceAndroidNotificationSound('adhan');

  /// Base offsets keep ids from colliding across features.
  static const int _prayerIdBase = 1000;

  /// Separate bands so the three calls for one prayer replace themselves on a
  /// reschedule without ever overwriting each other. Both stay below
  /// [_tahajjudId].
  static const int _beforeIdBase = 1100;
  static const int _afterIdBase = 1200;
  static const int _tahajjudId = 2000;

  static const int _testId = 9000;
  static const int _testPrayerId = 9001;

  /// Which prayer the next test fires as. Rotates so repeated taps walk
  /// through all six rather than showing Fajr every time.
  static int _testCursor = 0;

  Future<void> init({NotificationTapHandler? onTap}) async {
    if (_ready) return;
    _onTap = onTap;

    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
    } on Object catch (error) {
      debugPrint('Layla Pro: falling back to UTC timezone ($error)');
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Asked for explicitly after onboarding instead of at launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        if (payload != null && payload.isNotEmpty) _onTap?.call(payload);
      },
    );

    await _createAndroidChannels();
    _ready = true;
  }

  Future<void> _createAndroidChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannel,
        'Prayer reminders',
        description: 'A reminder when each prayer time begins.',
        importance: Importance.high,
        sound: _adhanAndroid,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _focusChannel,
        'Prayer focus',
        description:
            'Opens the prayer focus screen at the start of a prayer window.',
        importance: Importance.max,
        sound: _adhanAndroid,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _tahajjudChannel,
        'Tahajjud',
        description: 'An optional reminder for the last third of the night.',
        importance: Importance.defaultImportance,
        sound: _adhanAndroid,
      ),
    );
  }

  /// Requests notification permission (Android 13+ / iOS) and, on Android 12+,
  /// the exact-alarm grant that prayer timing depends on.
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final bool granted =
        await android?.requestNotificationsPermission() ?? false;
    // Without this, Android may delay the alarm past the prayer window.
    await android?.requestExactAlarmsPermission();
    return granted;
  }

  /// Schedules one prayer reminder. [index] is the prayer's ordinal (0–5) and
  /// keeps ids stable so re-scheduling replaces rather than duplicates.
  Future<void> schedulePrayer({
    required int index,
    required String prayerName,
    required String prayerId,
    required DateTime at,
    bool openFocusScreen = true,
  }) async {
    if (at.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      _prayerIdBase + index,
      '$prayerName has begun',
      _prayerWords[prayerId] ?? 'It is time for $prayerName.',
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          openFocusScreen ? _focusChannel : _reminderChannel,
          openFocusScreen ? 'Prayer focus' : 'Prayer reminders',
          importance: openFocusScreen ? Importance.max : Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          // Surfaces the focus screen over the lock screen where the OS allows
          // it. Requires USE_FULL_SCREEN_INTENT; see PRAYER_LOCK_LIMITATIONS.md.
          fullScreenIntent: openFocusScreen,
          styleInformation: const DefaultStyleInformation(true, true),
          sound: _adhanAndroid,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          sound: iosSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'noor://focus/$prayerId',
    );
  }

  /// [day] is the offset from today, so several nights can be queued without
  /// each one replacing the last.
  Future<void> scheduleTahajjud({required DateTime at, int day = 0}) async {
    if (at.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      _tahajjudId + day,
      'The last third of the night has begun',
      _prayerWords['tahajjud']!,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _tahajjudChannel,
          'Tahajjud',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          sound: _adhanAndroid,
        ),
        iOS: DarwinNotificationDetails(sound: iosSound),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'noor://tahajjud',
    );
  }

  /// Fires a real notification a few seconds out so the adhan can be heard
  /// without waiting for a prayer time.
  ///
  /// Deliberately *scheduled* rather than shown immediately: a notification
  /// delivered while the app is in the foreground is a different code path on
  /// iOS, and the delay leaves time to lock the phone and hear what actually
  /// happens at Fajr.
  Future<void> sendTestAdhan({Duration delay = const Duration(seconds: 5)}) {
    return _plugin.zonedSchedule(
      _testId,
      'Testing the adhan',
      'This is what you will hear when a prayer begins.',
      tz.TZDateTime.now(tz.local).add(delay),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _reminderChannel,
          'Prayer reminders',
          importance: Importance.high,
          priority: Priority.high,
          sound: _adhanAndroid,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          sound: iosSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// What the OS actually has queued.
  ///
  /// Worth surfacing: a reminder that was never scheduled and one that fired
  /// silently look identical from the user's side, and they are fixed in
  /// completely different places.
  Future<List<String>> pendingSummary() async {
    final List<PendingNotificationRequest> pending = await _plugin
        .pendingNotificationRequests();
    return pending
        .map((PendingNotificationRequest r) => r.title ?? 'Reminder #${r.id}')
        .toList();
  }

  /// Fires a real prayer reminder a few seconds out — same title, same words,
  /// same adhan, same channel as the genuine thing.
  ///
  /// Each tap advances to the next prayer, so all six lines can be read
  /// without waiting a day for them to come round.
  ///
  /// Returns the label it fired as, so the caller can say which one to expect.
  Future<String> sendTestPrayer({
    Duration delay = const Duration(seconds: 5),
  }) async {
    const List<({String id, String label})> order =
        <({String id, String label})>[
          (id: 'fajr', label: 'Fajr'),
          (id: 'dhuhr', label: 'Dhuhr'),
          (id: 'asr', label: 'Asr'),
          (id: 'maghrib', label: 'Maghrib'),
          (id: 'isha', label: '‘Isha'),
          (id: 'tahajjud', label: 'Tahajjud'),
        ];
    final ({String id, String label}) pick = order[_testCursor % order.length];
    _testCursor++;

    await _plugin.zonedSchedule(
      _testPrayerId,
      '${pick.label} has begun',
      _prayerWords[pick.id]!,
      tz.TZDateTime.now(tz.local).add(delay),
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _focusChannel,
          'Prayer focus',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          sound: _adhanAndroid,
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
          sound: iosSound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return pick.label;
  }

  /// The call before the adhan, and the one after the window has been open a
  /// while with nothing confirmed.
  ///
  /// Deliberately not the adhan sound. The adhan announces that the time has
  /// come; playing it ten minutes early, and again half an hour late, teaches
  /// people to stop believing it. These are a plain notification tone.
  Future<void> scheduleReminder({
    required int index,
    required String prayerName,
    required String prayerId,
    required DateTime at,
    required bool before,
    required int minutes,
  }) async {
    if (at.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      (before ? _beforeIdBase : _afterIdBase) + index,
      before
          ? '$prayerName is in $minutes minutes'
          : '$prayerName was $minutes minutes ago',
      before
          ? 'A moment to get ready.'
          : 'It is not too late — the window is still open.',
      tz.TZDateTime.from(at, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannel,
          'Prayer reminders',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: DefaultStyleInformation(true, true),
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'noor://focus/$prayerId',
    );
  }

  Future<void> cancelPrayer(int index) => _plugin.cancel(_prayerIdBase + index);

  Future<void> cancelReminder(int index, {required bool before}) =>
      _plugin.cancel((before ? _beforeIdBase : _afterIdBase) + index);

  /// Called the moment a prayer is confirmed.
  ///
  /// Without this the late reminder still fires: "Asr was 30 minutes ago, it
  /// is not too late" arriving at somebody who prayed twenty minutes ago is
  /// the app not paying attention, and it is the sort of thing that gets
  /// notifications turned off altogether.
  Future<void> cancelLateReminder(int index) =>
      cancelReminder(index, before: false);

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Set when the app was launched by tapping a notification, so the router can
  /// honour it after the first frame.
  Future<String?> launchPayload() async {
    final NotificationAppLaunchDetails? details = await _plugin
        .getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details!.notificationResponse?.payload;
    }
    return null;
  }
}
