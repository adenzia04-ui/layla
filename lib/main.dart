import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/prefs_service.dart';
import 'core/widgets/liquid_glass.dart';
import 'core/widgets/noor_globe.dart';
import 'core/widgets/setup_required_app.dart';
import 'core/audio/recitation_cache.dart';
import 'core/audio/recitation_handler.dart';
import 'core/audio/recitation_player.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: every screen — compass, focus, tasbih — is designed for it.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B1B34),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // A missing or unconfigured Firebase project is the single most likely
  // first-run failure. Catch it and say so on screen, rather than dying before
  // the first frame and leaving a black rectangle and a console trace nobody
  // is looking at on a phone.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error, stackTrace) {
    debugPrint('Layla Pro: Firebase failed to start — $error\n$stackTrace');
    runApp(SetupRequiredApp(error: error));
    return;
  }

  // Uncomment once App Check is registered in the Firebase console:
  // await FirebaseAppCheck.instance.activate(
  //   androidProvider: AndroidProvider.playIntegrity,
  //   appleProvider: AppleProvider.appAttest,
  // );

  // Decode the Earth textures now, so the dashboard globe never appears as a
  // flat disc while two 2048x1024 images decode. Deliberately not awaited —
  // it must not hold up first paint.
  unawaited(NoorGlobe.preload());
  // Compiled once at startup so the first tab switch is not the thing that
  // pays for it. Failure is handled inside — the bar falls back to painted
  // glass rather than to nothing.
  unawaited(LiquidGlassShader.load());

  // The recitation player — duas and the Qur'an. Registered with the OS
  // before the first frame so the lock screen and the earphones can drive
  // it; if the service will not start, the screens simply have no play
  // button rather than no app.
  try {
    recitationHandler = await AudioService.init(
      builder: RecitationHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.adenzia.layla.recitation',
        androidNotificationChannelName: 'Recitation',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } on Object catch (e) {
    debugPrint('Layla Pro: recitation service unavailable ($e)');
  }

  await RecitationCache.init();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await NotificationService.instance.init();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Layla Pro: uncaught framework error — ${details.exception}');
  };

  runApp(
    ProviderScope(
      overrides: <Override>[sharedPrefsProvider.overrideWithValue(prefs)],
      child: const NoorApp(),
    ),
  );
}
