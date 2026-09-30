import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/quran_prefs.dart';
import '../../domain/quran_data.dart';

/// One ayah in the reader: the Arabic large and right-aligned, then the
/// transliteration and the translation underneath, whichever of the three
/// are switched on. A thin gold edge marks the one being recited.
class AyahCard extends StatelessWidget {
  const AyahCard({
    super.key,
    required this.ayah,
    required this.lines,
    required this.scale,
    required this.playing,
    required this.current,
    required this.onPlay,
    required this.onTafsir,
  });

  final Ayah ayah;
  final Set<ReaderLine> lines;
  final double scale;

  /// This ayah is the one sounding right now.
  final bool current;

  /// …and it is playing rather than paused.
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onTafsir;

  @override
  Widget build(BuildContext context) {
    final bool arabic = lines.contains(ReaderLine.arabic);
    final bool translit = lines.contains(ReaderLine.transliteration);
    final bool english = lines.contains(ReaderLine.translation);

    return AnimatedContainer(
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
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: ayah.arabic),
                    const TextSpan(text: ' '),
                    // The ayah's number in the mushaf's own style: the
                    // end-of-ayah mark carries it.
                    TextSpan(
                      text: ' ${_arabicNumeral(ayah.number)} ',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 22 * scale,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                style: AppType.quran(
                  28 * scale,
                ).copyWith(color: AppColors.cream, height: 2.1),
              ),
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
          if (english) ...<Widget>[
            Text(
              ayah.translation,
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
              _Badge(number: ayah.number, current: current),
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
                icon: Icons.menu_book_outlined,
                tooltip: 'Tafsir (Ibn Kathir)',
                onTap: onTafsir,
              ),
              _Action(
                icon: Icons.copy_rounded,
                tooltip: 'Copy',
                onTap: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          '${ayah.arabic}\n\n${ayah.translation}\n'
                          '— Qur’an ${ayah.key}',
                    ),
                  );
                  if (context.mounted) context.showMessage('Copied.');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _arabicNumeral(int n) => n
      .toString()
      .split('')
      .map((String d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)])
      .join();
}

class _Badge extends StatelessWidget {
  const _Badge({required this.number, required this.current});

  final int number;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: Radii.chip,
        border: Border.all(
          color: current ? AppColors.gold : AppColors.navyLine,
        ),
        color: current ? AppColors.gold.withValues(alpha: 0.14) : null,
      ),
      child: Text(
        'Ayah $number',
        style: AppType.label.copyWith(
          color: current ? AppColors.gold : AppColors.mistFaint,
        ),
      ),
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
