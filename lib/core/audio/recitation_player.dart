import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'recitation_handler.dart';

/// The one handler, created in `main` before the first frame because
/// `audio_service` has to own it from the start of the process. Null in tests
/// and on any run where the service did not come up; every screen that
/// listens treats that as "no player", not as an error.
RecitationHandler? recitationHandler;

final Provider<RecitationHandler?> recitationHandlerProvider =
    Provider<RecitationHandler?>((Ref ref) => recitationHandler);

/// What is being recited, or null. A stream so a list can mark the row that
/// is playing and a detail screen can move its slider.
final StreamProvider<NowPlaying?> nowPlayingProvider =
    StreamProvider<NowPlaying?>((Ref ref) {
      final RecitationHandler? handler = ref.watch(recitationHandlerProvider);
      if (handler == null) return const Stream<NowPlaying?>.empty();
      return handler.nowPlaying;
    });
