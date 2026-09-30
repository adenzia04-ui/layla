import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/quran_prefs.dart';
import '../../application/quran_word.dart';
import '../../application/tafsir_service.dart';
import '../../domain/ayah_words.dart';
import '../../domain/quran_data.dart';
import '../../domain/translations.dart';

/// One ayah in the reader: the Arabic large and right-aligned, then the
/// transliteration and the chosen translations underneath, whichever are
/// switched on. A thin gold edge marks the one being recited, and inside
/// it the word being spoken warms to gold as the voice reaches it. Tapping
/// the ayah opens Ibn Kathir's tafsir right under it; tapping again folds
/// it away.
class AyahCard extends ConsumerWidget {
  const AyahCard({
    super.key,
    required this.ayah,
    required this.lines,
    required this.translationIds,
    required this.scale,
    required this.playing,
    required this.current,
    required this.tafsirOpen,
    required this.onPlay,
    required this.onToggleTafsir,
  });

  final Ayah ayah;
  final Set<ReaderLine> lines;
  final List<String> translationIds;
  final double scale;

  /// This ayah is the one sounding right now.
  final bool current;

  /// …and it is playing rather than paused.
  final bool playing;
  final bool tafsirOpen;
  final VoidCallback onPlay;
  final VoidCallback onToggleTafsir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool arabic = lines.contains(ReaderLine.arabic);
    final bool translit = lines.contains(ReaderLine.transliteration);
    final bool english = lines.contains(ReaderLine.translation);

    // Only the card being recited follows the word, and it rebuilds only
    // when the word changes — not on every tick of the position.
    final int word = current
        ? ref.watch(
            spokenWordProvider.select(
              (SpokenWord? w) =>
                  w != null && w.surah == ayah.surah && w.ayah == ayah.number
                  ? w.word
                  : 0,
            ),
          )
        : 0;

    return InkWell(
      onTap: onToggleTafsir,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.lg,
          Insets.sm,
        ),
        decoration: BoxDecoration(
          color: current
              ? AppColors.gold.withValues(alpha: 0.07)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: current ? AppColors.gold : Colors.transparent,
              width: 2,
            ),
            bottom: const BorderSide(color: AppColors.navyLine),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (arabic) ...<Widget>[
              ArabicWords(
                arabic: ayah.arabic,
                number: ayah.number,
                scale: scale,
                litWord: word,
              ),
              const SizedBox(height: Insets.md),
            ],
            if (translit && ayah.transliteration.isNotEmpty) ...<Widget>[
              Text(
                ayah.transliteration,
                style: AppType.body.copyWith(
                  fontSize: 15 * scale,
                  fontStyle: FontStyle.italic,
                  color: AppColors.mist,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: Insets.md),
            ],
            if (english)
              for (final String id in translationIds)
                if (ayah.translations[id] case final String text) ...<Widget>[
                  // The source is named only when more than one is shown;
                  // one translation is just "the translation".
                  if (translationIds.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        translationById(id).name.toUpperCase(),
                        style: AppType.label.copyWith(
                          fontSize: 10,
                          color: AppColors.goldDim,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: AppType.body.copyWith(
                      fontSize: 16 * scale,
                      color: AppColors.cream,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                ],
            Row(
              children: <Widget>[
                _Marker(ayah: ayah, current: current),
                const Spacer(),
                _Action(
                  icon: playing
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  tooltip: playing ? 'Pause' : 'Play from this ayah',
                  highlighted: current,
                  onTap: onPlay,
                ),
                _Action(
                  icon: tafsirOpen
                      ? Icons.menu_book_rounded
                      : Icons.menu_book_outlined,
                  tooltip: tafsirOpen ? 'Hide tafsir' : 'Tafsir (Ibn Kathir)',
                  highlighted: tafsirOpen,
                  onTap: onToggleTafsir,
                ),
                _Action(
                  icon: Icons.copy_rounded,
                  tooltip: 'Copy',
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            '${ayah.arabic}\n\n${ayah.translations[translationIds.first] ?? ayah.translation}\n'
                            '— Qur’an ${ayah.key}',
                      ),
                    );
                    if (context.mounted) context.showMessage('Copied.');
                  },
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: tafsirOpen
                  ? _TafsirInline(ayah: ayah, scale: scale)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  static String arabicNumeral(int n) => n
      .toString()
      .split('')
      .map((String d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)])
      .join();
}

/// The ayah's Arabic, one widget per word so a word can warm to gold as
/// it is spoken. Laid out right to left and wrapped like a line of text;
/// the ayah-end mark carries the number, the way the mushaf sets it.
class ArabicWords extends StatelessWidget {
  const ArabicWords({
    super.key,
    required this.arabic,
    required this.number,
    required this.scale,
    required this.litWord,
  });

  final String arabic;
  final int number;
  final double scale;

  /// 1-based word (marks not counted) to light, or 0 for none.
  final int litWord;

  @override
  Widget build(BuildContext context) {
    final List<String> tokens = ayahTokens(arabic);
    final int lit = wordToken(tokens, litWord);
    final double size = 28 * scale;
    final TextStyle base = AppType.quran(
      size,
    ).copyWith(color: AppColors.cream, height: 1.9);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        spacing: size * 0.24,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: <Widget>[
          for (int i = 0; i < tokens.length; i++)
            _Word(text: tokens[i], lit: i == lit, base: base),
          Text(
            AyahCard.arabicNumeral(number),
            style: base.copyWith(color: AppColors.gold, fontSize: size * 0.8),
          ),
        ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({required this.text, required this.lit, required this.base});

  final String text;
  final bool lit;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    // The word brightens and a soft glow gathers under it, then both ease
    // away as the voice moves on — a lantern passing along the line, not a
    // marker jumping from word to word.
    return AnimatedDefaultTextStyle(
      duration: Duration(milliseconds: lit ? 140 : 420),
      curve: Curves.easeOutCubic,
      style: lit
          ? base.copyWith(
              color: AppColors.goldSoft,
              shadows: <Shadow>[
                Shadow(
                  color: AppColors.gold.withValues(alpha: 0.75),
                  blurRadius: 18,
                ),
                Shadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 4,
                ),
              ],
            )
          : base.copyWith(
              shadows: <Shadow>[
                Shadow(
                  color: AppColors.gold.withValues(alpha: 0),
                  blurRadius: 18,
                ),
                Shadow(
                  color: AppColors.gold.withValues(alpha: 0),
                  blurRadius: 4,
                ),
              ],
            ),
      child: Text(text),
    );
  }
}

/// Ibn Kathir, unfolded under the ayah. Fetched the first time, kept after.
class _TafsirInline extends ConsumerWidget {
  const _TafsirInline({required this.ayah, required this.scale});

  final Ayah ayah;
  final double scale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> tafsir = ref.watch(tafsirProvider(ayah.key));
    return Container(
      margin: const EdgeInsets.only(top: Insets.sm, bottom: Insets.sm),
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.navyElevated.withValues(alpha: 0.7),
        borderRadius: Radii.card,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TAFSIR IBN KATHIR',
            style: AppType.label.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: Insets.sm),
          tafsir.when(
            data: (String text) => SelectableText(
              text,
              style: AppType.body.copyWith(
                fontSize: 15 * scale,
                color: AppColors.cream,
                height: 1.65,
              ),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.lg),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (Object e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The tafsir could not be fetched. It needs a signal the '
                  'first time; after that it is kept on the phone.',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
                const SizedBox(height: Insets.md),
                GhostButton(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  expand: false,
                  onPressed: () => ref.invalidate(tafsirProvider(ayah.key)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Abridged English edition, via quran.com.',
            style: AppType.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.mistFaint,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ayah's place, set the way a mushaf's margin would: the number in
/// its ornate brackets, and the reference beside it in small caps. No
/// pill, no border — a footnote, not a button.
class _Marker extends StatelessWidget {
  const _Marker({required this.ayah, required this.current});

  final Ayah ayah;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final Color ink = current ? AppColors.gold : AppColors.mistFaint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '﴿${AyahCard.arabicNumeral(ayah.number)}﴾',
          textDirection: TextDirection.rtl,
          style: AppType.arabic(15, height: 1).copyWith(color: ink),
        ),
        const SizedBox(width: Insets.sm),
        Text(
          '${ayah.surah}:${ayah.number}',
          style: AppType.label.copyWith(color: ink, letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      icon: Icon(
        icon,
        size: 22,
        color: highlighted ? AppColors.gold : AppColors.mistFaint,
      ),
      onPressed: onTap,
    );
  }
}
