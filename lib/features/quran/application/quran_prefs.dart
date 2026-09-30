import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../domain/quran_data.dart';
import '../domain/quran_queue.dart';
import '../domain/reciters.dart';

/// The bundled book, once.
final FutureProvider<Quran> quranProvider = FutureProvider<Quran>(
  (Ref ref) => loadQuran(),
);

/// Which lines the reader shows. At least one stays on: a reader showing
/// nothing is not a setting anyone means to choose.
enum ReaderLine { arabic, transliteration, translation }

final NotifierProvider<ReaderLines, Set<ReaderLine>> readerLinesProvider =
    NotifierProvider<ReaderLines, Set<ReaderLine>>(ReaderLines.new);

class ReaderLines extends Notifier<Set<ReaderLine>> {
  @override
  Set<ReaderLine> build() {
    final Set<String> saved = ref.read(prefsProvider).quranLines;
    final Set<ReaderLine> lines = <ReaderLine>{
      for (final ReaderLine l in ReaderLine.values)
        if (saved.contains(l.name)) l,
    };
    return lines.isEmpty ? <ReaderLine>{ReaderLine.arabic} : lines;
  }

  Future<void> toggle(ReaderLine line) async {
    final Set<ReaderLine> next = <ReaderLine>{...state};
    if (next.contains(line)) {
      if (next.length == 1) return;
      next.remove(line);
    } else {
      next.add(line);
    }
    state = next;
    await ref
        .read(prefsProvider)
        .setQuranLines(next.map((ReaderLine l) => l.name).toSet());
  }
}

/// The reader's text size, as a multiplier. Small steps, remembered.
final NotifierProvider<ReaderScale, double> readerScaleProvider =
    NotifierProvider<ReaderScale, double>(ReaderScale.new);

class ReaderScale extends Notifier<double> {
  static const double min = 0.8;
  static const double max = 1.6;
  static const double step = 0.1;

  @override
  double build() => ref.read(prefsProvider).quranTextScale.clamp(min, max);

  Future<void> bump(int direction) async {
    final double next = (state + direction * step).clamp(min, max);
    state = double.parse(next.toStringAsFixed(2));
    await ref.read(prefsProvider).setQuranTextScale(state);
  }
}

final NotifierProvider<ReciterChoice, Reciter> reciterProvider =
    NotifierProvider<ReciterChoice, Reciter>(ReciterChoice.new);

class ReciterChoice extends Notifier<Reciter> {
  @override
  Reciter build() => reciterById(ref.read(prefsProvider).quranReciter);

  Future<void> set(Reciter r) async {
    state = r;
    await ref.read(prefsProvider).setQuranReciter(r.id);
  }
}

final NotifierProvider<PlayModeChoice, PlayMode> playModeProvider =
    NotifierProvider<PlayModeChoice, PlayMode>(PlayModeChoice.new);

class PlayModeChoice extends Notifier<PlayMode> {
  @override
  PlayMode build() => ref.read(prefsProvider).quranPlayMode == 'ayah'
      ? PlayMode.ayahByAyah
      : PlayMode.surah;

  Future<void> set(PlayMode m) async {
    state = m;
    await ref
        .read(prefsProvider)
        .setQuranPlayMode(m == PlayMode.ayahByAyah ? 'ayah' : 'surah');
  }
}

/// Times each ayah is read in ayah-by-ayah mode, 1–10.
final NotifierProvider<AyahRepeat, int> ayahRepeatProvider =
    NotifierProvider<AyahRepeat, int>(AyahRepeat.new);

class AyahRepeat extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).quranRepeat.clamp(1, 10);

  Future<void> set(int n) async {
    state = n.clamp(1, 10);
    await ref.read(prefsProvider).setQuranRepeat(state);
  }
}

/// Start the surah again when it ends.
final NotifierProvider<LoopSurah, bool> loopSurahProvider =
    NotifierProvider<LoopSurah, bool>(LoopSurah.new);

class LoopSurah extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).quranLoopSurah;

  Future<void> set(bool v) async {
    state = v;
    await ref.read(prefsProvider).setQuranLoopSurah(v);
  }
}

/// Where the reader was left — `2:255` — so "Continue" opens there.
final NotifierProvider<LastRead, String?> lastReadProvider =
    NotifierProvider<LastRead, String?>(LastRead.new);

class LastRead extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).quranLastRead;

  Future<void> set(String key) async {
    if (state == key) return;
    state = key;
    await ref.read(prefsProvider).setQuranLastRead(key);
  }
}

/// The page the mushaf was left open at.
final NotifierProvider<LastPage, int> lastPageProvider =
    NotifierProvider<LastPage, int>(LastPage.new);

class LastPage extends Notifier<int> {
  @override
  int build() =>
      ref.read(prefsProvider).quranLastPage.clamp(1, Quran.pageCount);

  Future<void> set(int page) async {
    if (state == page) return;
    state = page;
    await ref.read(prefsProvider).setQuranLastPage(page);
  }
}
