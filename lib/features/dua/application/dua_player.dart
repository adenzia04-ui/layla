import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/services/prefs_service.dart';
import '../domain/dua_text.dart';
import 'dua_audio_handler.dart';

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

/// The dua being read from [section], if the player is on that section.
///
/// Null when nothing plays, or when what plays is another section or the
/// Qur'an — so a section's list never marks a row for a recitation that is
/// not its own.
NowPlaying? duaNowPlaying(NowPlaying? now, DuaTextSection section) =>
    now != null && now.owner == duaOwner(section.section) ? now : null;

/// Starts [section] from [startNumber], each dua read the remembered number
/// of times. Nothing happens without a player.
Future<void> playDuaSection(
  WidgetRef ref, {
  required DuaTextSection section,
  required String heading,
  required int startNumber,
}) async {
  final RecitationHandler? handler = ref.read(recitationHandlerProvider);
  if (handler == null) return;
  final int repeat = ref.read(duaRepeatProvider);
  final List<RecitationTrack> tracks = duaTracks(
    section,
    heading: heading,
    repeat: repeat,
  );
  final int start = tracks.indexWhere(
    (RecitationTrack t) => t.group == '$startNumber',
  );
  if (start < 0) return;
  await handler.load(tracks, owner: duaOwner(section.section), start: start);
}
