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
  bool _hasArabic = true;

  Future<void> _prepare() async {
    if (_ready) return;
    try {
      // Asked before the language is set, because setLanguage succeeds on a
      // phone that cannot actually speak it and then says nothing.
      _hasArabic = await _tts.isLanguageAvailable('ar-SA') == true;
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

  /// Speaks the Arabic, and says whether it managed to.
  ///
  /// It used to return nothing and swallow every failure, which is the right
  /// instinct — a missing voice must not break the page — and the wrong
  /// outcome: on Android the button was silent for two separate reasons at
  /// once, and a silent button with no message is indistinguishable from a
  /// broken one. The caller can now tell the person why nothing happened.
  Future<bool> say(String arabic) async {
    await _prepare();
    if (!_hasArabic) return false;
    try {
      await _tts.stop();
      await _tts.speak(arabic);
      return true;
    } catch (e) {
      debugPrint('Layla Pro: speech failed ($e)');
      return false;
    }
  }

  Future<void> stop() => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
