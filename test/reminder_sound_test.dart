import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/config/platform_features.dart';
import 'package:noor/core/services/notification_sounds.dart';

/// A reminder tone has to exist in two places at once.
///
/// The app plays the preview from a Flutter asset; Android plays the real
/// notification from `res/raw`, because a channel's sound must be a resource
/// the system can reach without the app running. Adding a tone and forgetting
/// the second copy is silent — the picker shows it, the preview plays, and the
/// reminder that actually matters falls back to the default tone weeks later.
void main() {
  group('Reminder sounds', () {
    test('every tone ships as a Flutter asset', () {
      for (final ReminderSound sound in ReminderSound.values) {
        expect(
          File(sound.asset).existsSync(),
          isTrue,
          reason: '${sound.name}: ${sound.asset} is missing',
        );
      }
    });

    test('every tone ships as an Android raw resource', () {
      const String raw = 'android/app/src/main/res/raw';
      for (final ReminderSound sound in ReminderSound.values) {
        final bool present = Directory(raw)
            .listSync()
            .whereType<File>()
            .any(
              (File f) =>
                  f.uri.pathSegments.last.split('.').first == sound.androidRaw,
            );
        expect(
          present,
          isTrue,
          reason:
              '${sound.name}: nothing named ${sound.androidRaw} in $raw, so '
              'Android would play its default tone',
        );
      }
    });

    test('raw names carry no extension, which Android would reject', () {
      for (final ReminderSound sound in ReminderSound.values) {
        expect(sound.androidRaw, isNot(contains('.')));
        expect(sound.androidRaw, isNotEmpty);
      }
    });
  });

  group('Platform features', () {
    test('off a phone, nothing platform-specific is promised', () {
      // Tests run on the Dart VM. Every one of these must read false there,
      // so a widget test can never render a switch only one platform honours.
      expect(Have.homeScreenWidgets, isFalse);
      expect(Have.liveActivity, isFalse);
      expect(Have.enforcedAppLock, isFalse);
    });
  });
}
