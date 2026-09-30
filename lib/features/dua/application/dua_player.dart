import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import 'dua_audio_handler.dart';

/// The one handler, created in `main` before the first frame because
/// `audio_service` has to own it from the start of the process. Null in tests
/// and on any run where the service did not come up; every screen that
/// listens treats that as "no player", not as an error.
DuaAudioHandler? duaAudioHandler;

final Provider<DuaAudioHandler?> duaAudioHandlerProvider =
    Provider<DuaAudioHandler?>((Ref ref) => duaAudioHandler);

/// What is being recited, or null. A stream so the list can mark the row
/// that is playing and the detail screen can move its slider.
final StreamProvider<DuaNowPlaying?> duaNowPlayingProvider =
    StreamProvider<DuaNowPlaying?>((Ref ref) {
      final DuaAudioHandler? handler = ref.watch(duaAudioHandlerProvider);
      if (handler == null) return const Stream<DuaNowPlaying?>.empty();
      return handler.nowPlaying;
    });

/// How many times each dua is read before the next one, 1–10. Remembered:
/// someone learning a section picks a number once and keeps it.
final NotifierProvider<DuaRepeat, int> duaRepeatProvider =
    NotifierProvider<DuaRepeat, int>(DuaRepeat.new);

class DuaRepeat extends Notifier<int> {
  static const int min = 1;
  static const int max = 10;

  @override
  int build() => ref.read(prefsProvider).duaRepeat.clamp(min, max);

  Future<void> set(int value) async {
    state = value.clamp(min, max);
    await ref.read(prefsProvider).setDuaRepeat(state);
  }
}
