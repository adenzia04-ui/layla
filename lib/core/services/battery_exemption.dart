import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Android will actually let a prayer reminder arrive.
///
/// The app books an exact alarm for every prayer and the phone is free to
/// ignore it. Stock Android usually does not; Samsung's One UI puts apps to
/// sleep by default, and a sleeping app's alarm arrives late or not at all.
/// For a prayer app that is the whole product failing silently — the alarm is
/// booked, the code is right, the notification never comes, and there is
/// nothing on screen to suggest why.
///
/// iPhone has no equivalent, which is why none of this existed: a scheduled
/// local notification on iOS simply arrives.
class BatteryExemption {
  const BatteryExemption();

  static const MethodChannel _channel = MethodChannel(
    'com.adenzia.layla/power',
  );

  /// True when the phone has agreed to leave Layla Pro alone.
  ///
  /// True on any platform that does not have the idea, so a screen asking
  /// this never shows an iPhone a problem it cannot have.
  Future<bool> get unrestricted async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('unrestricted') ?? true;
    } on MissingPluginException {
      return true;
    } on Object catch (e) {
      debugPrint('Layla Pro: battery state unreadable ($e)');
      return true;
    }
  }

  /// Opens the screen that holds the switch.
  Future<void> open() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openBatterySettings');
    } on Object catch (e) {
      debugPrint('Layla Pro: battery settings would not open ($e)');
    }
  }
}

final Provider<BatteryExemption> batteryExemptionProvider =
    Provider<BatteryExemption>((Ref ref) => const BatteryExemption());

/// Re-read whenever the screen that shows it comes back into view; coming
/// back from Settings is the only moment it changes.
final FutureProvider<bool> unrestrictedProvider = FutureProvider<bool>(
  (Ref ref) => ref.watch(batteryExemptionProvider).unrestricted,
);
