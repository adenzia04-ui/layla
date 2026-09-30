import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/quran_player.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';
import '../domain/reciters.dart';
import 'widgets/ayah_card.dart';
import 'widgets/quran_player_bar.dart';
import 'widgets/tafsir_sheet.dart';

/// One surah, ayah by ayah, with the words beside their meaning.
///
/// Arabic, transliteration and translation can each be shown or hidden and
/// the text sized up or down, and both are remembered. The ayah being
/// recited is marked and kept on screen, so the eye can follow the voice.
class SurahReaderScreen extends ConsumerStatefulWidget {
  const SurahReaderScreen({super.key, required this.surah, this.ayah});

  final int surah;

  /// Scrolls to this ayah on open.
  final int? ayah;

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  int? _followed;

  GlobalKey _keyFor(int ayah) => _keys[ayah] ??= GlobalKey();

  @override
  void initState() {
    super.initState();
    final int surah = widget.surah.clamp(1, 114);
    unawaited(
      ref.read(lastReadProvider.notifier).set('$surah:${widget.ayah ?? 1}'),
    );
    if (widget.ayah != null && widget.ayah! > 1) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reveal(widget.ayah!),
      );
    }
  }

  void _reveal(int ayah) {
    final BuildContext? c = _keys[ayah]?.currentContext;
    if (c == null) return;
    unawaited(
      Scrollable.ensureVisible(
        c,
        alignment: 0.15,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int surah = widget.surah.clamp(1, 114);
    final AsyncValue<Quran> quran = ref.watch(quranProvider);
    final Set<ReaderLine> lines = ref.watch(readerLinesProvider);
    final double scale = ref.watch(readerScaleProvider);
    final Reciter reciter = ref.watch(reciterProvider);
    final RecitationHandler? handler = ref.watch(recitationHandlerProvider);

    // Follow the reciter: when the ayah changes, bring it into view once.
    ref.listen<AsyncValue<NowPlaying?>>(nowPlayingProvider, (
      AsyncValue<NowPlaying?>? _,
      AsyncValue<NowPlaying?> next,
    ) {
      final NowPlaying? now = surahNowPlaying(next.valueOrNull, surah, reciter);
      if (now == null) return;
      final int a = ayahOf(now);
      if (a == _followed) return;
      _followed = a;
      unawaited(ref.read(lastReadProvider.notifier).set('$surah:$a'));
      _reveal(a);
    });

    final NowPlaying? now = surahNowPlaying(
      ref.watch(nowPlayingProvider).valueOrNull,
      surah,
      reciter,
    );
    final int? currentAyah = now == null ? null : ayahOf(now);

    return quran.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: Text(
            '$e',
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
        ),
      ),
      data: (Quran q) {
        final Surah s = q.surah(surah);
        final List<Ayah> ayahs = q.ayahsOf(surah);

        return Scaffold(
          backgroundColor: AppColors.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: BackButton(
              color: AppColors.cream,
              onPressed: () => context.pop(),
            ),
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(s.name, style: AppType.titleSm),
                Text(
                  '${s.meaning} · ${s.ayahCount} ayahs · '
                  '${s.isMakki ? 'Makkah' : 'Madinah'}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Smaller text',
                icon: const Icon(
                  Icons.text_decrease_rounded,
                  color: AppColors.mist,
                ),
                onPressed: () =>
                    unawaited(ref.read(readerScaleProvider.notifier).bump(-1)),
              ),
              IconButton(
                tooltip: 'Larger text',
                icon: const Icon(
                  Icons.text_increase_rounded,
                  color: AppColors.mist,
                ),
                onPressed: () =>
                    unawaited(ref.read(readerScaleProvider.notifier).bump(1)),
              ),
              const SizedBox(width: Insets.xs),
            ],
          ),
          body: Column(
            children: <Widget>[
              _LineChips(lines: lines),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  itemCount: ayahs.length + 1,
                  itemBuilder: (BuildContext context, int i) {
                    if (i == 0) return _SurahHead(surah: s, scale: scale);
                    final Ayah a = ayahs[i - 1];
                    final bool current = currentAyah == a.number;
                    return KeyedSubtree(
                      key: _keyFor(a.number),
                      child: AyahCard(
                        ayah: a,
                        lines: lines,
                        scale: scale,
                        current: current,
                        playing: current && (now?.playing ?? false),
                        onPlay: () {
                          unawaited(HapticFeedback.lightImpact());
                          if (handler == null) return;
                          if (current) {
                            unawaited(
                              now!.playing ? handler.pause() : handler.play(),
                            );
                          } else {
                            unawaited(
                              playSurah(
                                ref,
                                quran: q,
                                surah: surah,
                                ayah: a.number,
                              ),
                            );
                          }
                        },
                        onTafsir: () =>
                            unawaited(showTafsir(context, a, s.name)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: QuranPlayerBar(quran: q, surah: surah),
        );
      },
    );
  }
}

/// Which lines the reader shows. Any mix; never none.
class _LineChips extends ConsumerWidget {
  const _LineChips({required this.lines});

  final Set<ReaderLine> lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(ReaderLine line, String label) {
      final bool on = lines.contains(line);
      return Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: FilterChip(
          label: Text(label),
          selected: on,
          showCheckmark: false,
          onSelected: (_) {
            unawaited(HapticFeedback.selectionClick());
            unawaited(ref.read(readerLinesProvider.notifier).toggle(line));
          },
          selectedColor: AppColors.gold,
          backgroundColor: AppColors.navyElevated,
          labelStyle: AppType.label.copyWith(
            color: on ? AppColors.midnight : AppColors.mist,
          ),
          side: BorderSide(color: on ? AppColors.gold : AppColors.navyLine),
          shape: const StadiumBorder(),
        ),
      );
    }

    // A Wrap, not a Row: three chips fit an iPhone Pro Max with room to
    // spare and a small phone with none, and a Row would overflow there.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.xs,
        Insets.lg,
        Insets.sm,
      ),
      child: Wrap(
        runSpacing: Insets.xs,
        children: <Widget>[
          chip(ReaderLine.arabic, 'Arabic'),
          chip(ReaderLine.transliteration, 'Transliteration'),
          chip(ReaderLine.translation, 'Translation'),
        ],
      ),
    );
  }
}

/// The surah's name as the mushaf sets it, and the basmalah where the
/// mushaf prints it.
class _SurahHead extends StatelessWidget {
  const _SurahHead({required this.surah, required this.scale});

  final Surah surah;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.lg,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            decoration: BoxDecoration(
              borderRadius: Radii.card,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
            ),
            child: Text(
              'سُورَةُ ${surah.arabicName}',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppType.quran(26).copyWith(color: AppColors.goldSoft),
            ),
          ),
          // Al-Fatihah's basmalah is its first ayah and At-Tawbah has none;
          // the data marks both, so nothing is printed twice or invented.
          if (surah.hasBismillah) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: AppType.quran(26 * scale).copyWith(color: AppColors.cream),
            ),
          ],
        ],
      ),
    );
  }
}
