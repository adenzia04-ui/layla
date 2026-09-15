import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';
import 'prefs_service.dart';

/// What a prayer reminder sounds like.
///
/// The adhan is the default and the point of the app. The other three are
/// for people who pray in an office, a shared house, or beside a sleeping
/// child: a chime, a single bell, and a soft swell, none of them a jingle.
enum ReminderSound {
  adhan('Adhan', 'The call to prayer', 'adhan.caf', 'adhan'),
  chime('Chime', 'Two clear notes', 'chime.wav', 'chime'),
  bell('Bell', 'One deep strike', 'bell.wav', 'bell'),
  soft('Soft', 'A quiet swell, no attack', 'soft.wav', 'soft');

  const ReminderSound(this.label, this.hint, this.file, this.androidRaw);

  final String label;
  final String hint;
  final String file;

  /// The bare name of the copy in `android/app/src/main/res/raw`. Android
  /// plays notification sounds from resources, not from Flutter assets, so
  /// each tone ships twice — once for the preview the app plays itself, once
  /// where the system can reach it.
  final String androidRaw;

  /// Where the app plays it from, for the preview.
  String get asset => 'assets/sounds/$file';

  static ReminderSound byName(String? name) => ReminderSound.values.firstWhere(
    (ReminderSound s) => s.name == name,
    orElse: () => ReminderSound.adhan,
  );
}

/// The chosen sound, kept on the phone and applied to the service.
final NotifierProvider<ReminderSoundStore, ReminderSound>
reminderSoundProvider = NotifierProvider<ReminderSoundStore, ReminderSound>(
  ReminderSoundStore.new,
);

class ReminderSoundStore extends Notifier<ReminderSound> {
  static const String _key = 'reminder_sound';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  ReminderSound build() {
    final ReminderSound sound = ReminderSound.byName(_prefs.getString(_key));
    _apply(sound);
    // Best-effort: the file is copied where iOS looks for it. Nothing here
    // can fail loudly — a missing file means iOS plays its default tone.
    NotificationSounds.install(sound);
    return sound;
  }

  Future<void> set(ReminderSound sound) async {
    if (sound == state) return;
    await NotificationSounds.install(sound);
    _apply(sound);
    state = sound;
    await _prefs.setString(_key, sound.name);
    // Android cannot change a live channel's sound, so the channels are
    // rebuilt around the new one. Without this the picker moves and every
    // reminder keeps playing the tone chosen first.
    await NotificationService.instance.refreshAndroidSound();
  }

  void _apply(ReminderSound sound) {
    NotificationService.iosSound = sound.file;
    NotificationService.androidSound = sound.androidRaw;
  }
}

/// Puts a sound where iOS will find it.
///
/// A notification sound must be in the app bundle or in the app's own
/// `Library/Sounds`. The adhan ships in the bundle; the tones are Flutter
/// assets, copied across once, so the picker needs no Xcode project change.
abstract final class NotificationSounds {
  static Future<void> install(ReminderSound sound) async {
    if (!Platform.isIOS || sound == ReminderSound.adhan) return;
    try {
      final Directory lib = await getLibraryDirectory();
      final Directory dir = Directory('${lib.path}/Sounds');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final File target = File('${dir.path}/${sound.file}');
      if (target.existsSync()) return;
      final ByteData data = await rootBundle.load(sound.asset);
      await target.writeAsBytes(data.buffer.asUint8List(), flush: true);
    } on Object catch (error) {
      debugPrint('Layla Pro: could not install ${sound.file} — $error');
    }
  }
}
