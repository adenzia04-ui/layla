import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Says a name aloud in Arabic, through the phone's own Arabic voice.
///
/// Speech rather than recordings: ninety-nine audio files would be a
/// download for something the phone can already do offline, and the voice is
/// clear enough to settle the one question people have — how it is said.
final Provider<NameSpeaker> nameSpeakerProvider = Provider<NameSpeaker>((
  Ref ref,
) {
  final NameSpeaker speaker = NameSpeaker();
  ref.onDispose(speaker.dispose);
  return speaker;
});

class NameSpeaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _prepare() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('ar-SA');
      await _tts.setSpeechRate(0.38);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setSharedInstance(true);
    } catch (e) {
      debugPrint('Layla Pro: speech setup failed ($e)');
    }
    _ready = true;
  }

  /// Speaks the Arabic. Errors are silent: a voice that is missing on this
  /// phone should never break the page.
  Future<void> say(String arabic) async {
    await _prepare();
    try {
      await _tts.stop();
      await _tts.speak(arabic);
    } catch (e) {
      debugPrint('Layla Pro: speech failed ($e)');
    }
  }

  Future<void> stop() => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
