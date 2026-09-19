import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/widget_snapshot.dart';

final Provider<WidgetBridge> widgetBridgeProvider = Provider<WidgetBridge>(
  (Ref ref) => const WidgetBridge(),
);

/// Drives the Live Activity, and nudges the home-screen widgets to redraw.
///
/// Everything here degrades to a silent no-op when the widget extension is not
/// installed, so the app behaves identically on a plain checkout.
class WidgetBridge {
  const WidgetBridge();

  static const MethodChannel _channel = MethodChannel(
    'com.noorapp.noor/widgets',
  );

  /// Hands the widgets the little they cannot work out alone — the streak and
  /// today's confirmed count — and redraws them.
  ///
  /// Prayer times are deliberately *not* sent: the widgets compute those from
  /// location and their own configuration using the same Adhan maths as the
  /// app, so the two cannot drift. Anything behind the user's login has to
  /// travel through the App Group instead.
  Future<void> publishSnapshot(WidgetSnapshot snapshot) => _invoke(
    'publishSnapshot',
    <String, Object?>{'snapshot': snapshot.toJson()},
  );

  /// Nudges WidgetKit to rebuild its timelines without changing shared state.
  /// Hands the widget a freshly drawn globe frame.
  ///
  /// Bytes rather than a path: the app's documents directory is not readable
  /// from the extension, so the picture has to cross into the App Group and
  /// only the native side can put it there.
  Future<void> publishGlobe(Uint8List png) =>
      _invoke('publishGlobe', <String, Object?>{'png': png});

  Future<void> reloadWidgets() => _invoke('reloadWidgets');

  // ── Live Activity ────────────────────────────────────────────────────

  /// Starts (or updates) the Lock Screen / Dynamic Island activity for the
  /// prayer window.
  Future<void> startLiveActivity(WidgetSnapshot snapshot) => _invoke(
    'startLiveActivity',
    <String, Object?>{'snapshot': snapshot.toJson()},
  );

  Future<void> updateLiveActivity(WidgetSnapshot snapshot) => _invoke(
    'updateLiveActivity',
    <String, Object?>{'snapshot': snapshot.toJson()},
  );

  Future<void> endLiveActivity() => _invoke('endLiveActivity');

  Future<bool> get liveActivitiesEnabled async =>
      await _invoke<bool>('liveActivitiesEnabled') ?? false;

  /// The `layla://` link this launch began with, if a widget tap began it.
  ///
  /// Only Android answers. Flutter's deep linking does not carry a
  /// scheme-only url — `layla://qibla` has no path — through a cold start, so
  /// by the time the router looks, the destination is already gone and the
  /// tap has opened the home screen. The launch intent still holds it, and
  /// this asks for it. Answered once: a second call returns null, so a link
  /// cannot be spent twice.
  Future<String?> consumeLaunchLink() => _invoke<String>('consumeLaunchLink');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      debugPrint('Layla Pro: widget "$method" failed — ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
