import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/quran_player.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';
import '../domain/translations.dart';
import 'widgets/ayah_card.dart';
import 'widgets/quran_player_bar.dart';

/// One surah, ayah by ayah, with the words beside their meaning.
///
/// Arabic, transliteration and any mix of five translations can be shown
/// or hidden and the text sized up or down, all remembered. Tapping an
/// ayah unfolds Ibn Kathir under it. The ayah being recited is marked and
/// kept on screen, so the eye can follow the voice.
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
  final Set<int> _tafsirOpen = <int>{};
  int? _followed;

  GlobalKey _keyFor(int ayah) => _keys[ayah] ??= GlobalKey();

  @override
  void initState() {
    super.initState();
    final int surah = widget.surah.clamp(1, 114);
    // After the first frame, not in initState: a provider must not change
    // while the tree is building, and this one is watched by the home
    // screen underneath.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(lastReadProvider.notifier).set('$surah:${widget.ayah ?? 1}'),
      );
      if (widget.ayah != null && widget.ayah! > 1) _reveal(widget.ayah!);
    });
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
    final List<String> translationIds = ref.watch(translationsProvider);
    final double scale = ref.watch(readerScaleProvider);
    final RecitationHandler? handler = ref.watch(recitationHandlerProvider);

    // Follow the reciter: when the ayah changes, bring it into view once.
    ref.listen<AsyncValue<NowPlaying?>>(nowPlayingProvider, (
      AsyncValue<NowPlaying?>? _,
      AsyncValue<NowPlaying?> next,
    ) {
      final NowPlaying? now = surahNowPlaying(next.valueOrNull, surah);
      if (now == null) return;
      final int a = ayahOf(now);
      if (a == 0 || a == _followed) return;
      _followed = a;
      unawaited(ref.read(lastReadProvider.notifier).set('$surah:$a'));
      _reveal(a);
    });

    final NowPlaying? now = surahNowPlaying(
      ref.watch(nowPlayingProvider).valueOrNull,
      surah,
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
                  '${s.isMakki ? 'Makkah' : 'Madinah'} · '
                  'revealed ${_ordinal(s.revelationOrder)}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            actions: <Widget>[
              IconButton(
                tooltip: 'Open in the mushaf',
                icon: const Icon(
                  Icons.auto_stories_outlined,
                  color: AppColors.mist,
                ),
                onPressed: () => context.push(Routes.quranMushafOf(surah)),
              ),
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
              _LineChips(
                lines: lines,
                translationIds: translationIds,
                onTranslations: () => _pickTranslations(context),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  itemCount: ayahs.length + 1,
                  itemBuilder: (BuildContext context, int i) {
                    if (i == 0) {
                      return _SurahHead(
                        surah: s,
                        scale: scale,
                        juz: ayahs.first.juz,
                      );
                    }
                    final Ayah a = ayahs[i - 1];
                    final bool current = currentAyah == a.number;
                    return KeyedSubtree(
                      key: _keyFor(a.number),
                      child: AyahCard(
                        ayah: a,
                        lines: lines,
                        translationIds: translationIds,
                        scale: scale,
                        current: current,
                        playing: current && (now?.playing ?? false),
                        tafsirOpen: _tafsirOpen.contains(a.number),
                        onToggleTafsir: () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() {
                            if (!_tafsirOpen.remove(a.number)) {
                              _tafsirOpen.add(a.number);
                            }
                          });
                        },
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

  Future<void> _pickTranslations(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.navy,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        builder: (BuildContext context) => const _TranslationsSheet(),
      );

  static String _ordinal(int n) {
    if (n <= 0) return '—';
    final int mod100 = n % 100;
    final String suffix = (mod100 >= 11 && mod100 <= 13)
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suffix';
  }
}

/// Which lines the reader shows. Any mix; never none. The translation chip
/// also opens the choice of which translations.
class _LineChips extends ConsumerWidget {
  const _LineChips({
    required this.lines,
    required this.translationIds,
    required this.onTranslations,
  });

  final Set<ReaderLine> lines;
  final List<String> translationIds;
  final VoidCallback onTranslations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(ReaderLine line, String label, {VoidCallback? onLong}) {
      final bool on = lines.contains(line);
      return Padding(
        padding: const EdgeInsets.only(right: Insets.sm),
        child: GestureDetector(
          onLongPress: onLong,
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
        ),
      );
    }

    final String trLabel = translationIds.length == 1
        ? translationById(translationIds.first).name
        : '${translationIds.length} translations';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.xs,
        Insets.lg,
        Insets.sm,
      ),
      child: Wrap(
        runSpacing: Insets.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          chip(ReaderLine.arabic, 'Arabic'),
          chip(ReaderLine.transliteration, 'Transliteration'),
          chip(ReaderLine.translation, trLabel),
          // Which translations: its own small button, so the chip stays a
          // plain on/off like the other two.
          ActionChip(
            avatar: const Icon(
              Icons.tune_rounded,
              size: 16,
              color: AppColors.mist,
            ),
            label: const Text('Translations'),
            labelStyle: AppType.label.copyWith(color: AppColors.mist),
            backgroundColor: AppColors.navyElevated,
            side: const BorderSide(color: AppColors.navyLine),
            shape: const StadiumBorder(),
            onPressed: onTranslations,
          ),
        ],
      ),
    );
  }
}

class _TranslationsSheet extends ConsumerWidget {
  const _TranslationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> chosen = ref.watch(translationsProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Translations', style: AppType.titleLg),
            const SizedBox(height: Insets.xs),
            Text(
              'Show one, or a few together to compare.',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.md),
            for (final Translation t in translations)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: chosen.contains(t.id),
                activeColor: AppColors.gold,
                checkColor: AppColors.midnight,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(t.name, style: AppType.titleSm),
                subtitle: Text(
                  '${t.author} — ${t.note}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 12,
                    color: AppColors.mistFaint,
                  ),
                ),
                onChanged: (_) => unawaited(
                  ref.read(translationsProvider.notifier).toggle(t.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The surah's name as the mushaf sets it, where it sits in the book, and
/// the basmalah where the mushaf prints it.
class _SurahHead extends StatelessWidget {
  const _SurahHead({
    required this.surah,
    required this.scale,
    required this.juz,
  });

  final Surah surah;
  final double scale;
  final int juz;

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
            child: Column(
              children: <Widget>[
                Text(
                  'سُورَةُ ${surah.arabicName}',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: AppType.quran(26).copyWith(color: AppColors.goldSoft),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Surah ${surah.number} · Juz $juz · '
                  'pages ${surah.firstPage}–${surah.lastPage} · '
                  'revelation order ${surah.revelationOrder}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                ),
              ],
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
