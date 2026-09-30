import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/recitation_handler.dart';
import '../../../../core/audio/recitation_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/player_controls.dart';
import '../../application/quran_player.dart';
import '../../application/quran_prefs.dart';
import '../../domain/quran_data.dart';
import '../../domain/quran_queue.dart';
import '../../domain/reciters.dart';

/// The bar under a surah: who is reciting, which ayah, and the transport.
///
/// The first press of play asks how — whole surah or ayah by ayah, how many
/// times each, which voice, whether to loop — and remembers the answer, so
/// the next press just plays. The gear reopens the same sheet.
class QuranPlayerBar extends ConsumerWidget {
  const QuranPlayerBar({
    super.key,
    required this.quran,
    required this.surah,
    this.fromAyah = 1,
  });

  final Quran quran;
  final int surah;

  /// Where a fresh play starts — the page's first ayah in the mushaf, the
  /// top of the surah in the reader.
  final int fromAyah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecitationHandler? handler = ref.watch(recitationHandlerProvider);
    if (handler == null) return const SizedBox.shrink();

    final Reciter reciter = ref.watch(reciterProvider);
    final NowPlaying? now = surahNowPlaying(
      ref.watch(nowPlayingProvider).valueOrNull,
      surah,
      reciter,
    );
    final Surah s = quran.surah(surah);
    final bool playing = now?.playing ?? false;

    Future<void> start() =>
        playSurah(ref, quran: quran, surah: surah, ayah: fromAyah);

    return Material(
      color: AppColors.navy,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.sm,
            Insets.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      now == null
                          ? s.name
                          : 'Ayah ${ayahOf(now)} of ${s.ayahCount}'
                                '${now.track.passes > 1 ? ' · ${now.track.pass}/${now.track.passes}' : ''}',
                      style: AppType.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      now == null
                          ? '${reciter.name} · tap play'
                          : now.loading
                          ? 'Loading…'
                          : reciter.name,
                      style: AppType.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.mistFaint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PlayerTransport(
                compact: true,
                playing: playing,
                onPlay: () async {
                  unawaited(HapticFeedback.lightImpact());
                  if (now == null) {
                    // Asked once, then remembered.
                    final bool go = await showPlayOptions(context, ref);
                    if (go) await start();
                  } else if (playing) {
                    await handler.pause();
                  } else {
                    await handler.play();
                  }
                },
                onPrevious: now == null ? null : handler.skipToPrevious,
                onNext: now == null ? null : handler.skipToNext,
                previousLabel: 'Previous ayah',
                nextLabel: 'Next ayah',
              ),
              IconButton(
                tooltip: 'Playback options',
                icon: const Icon(Icons.tune_rounded, color: AppColors.mist),
                onPressed: () async {
                  final bool go = await showPlayOptions(context, ref);
                  // Changed while playing: take effect now, from this ayah.
                  if (go && now != null) {
                    await playSurah(
                      ref,
                      quran: quran,
                      surah: surah,
                      ayah: ayahOf(now),
                    );
                  } else if (go) {
                    await start();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice, mode, repeats, loop. Returns true when "Play" was pressed.
Future<bool> showPlayOptions(BuildContext context, WidgetRef ref) async {
  final bool? go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.navy,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) => const _PlayOptionsSheet(),
  );
  return go ?? false;
}

class _PlayOptionsSheet extends ConsumerWidget {
  const _PlayOptionsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Reciter reciter = ref.watch(reciterProvider);
    final PlayMode mode = ref.watch(playModeProvider);
    final int repeat = ref.watch(ayahRepeatProvider);
    final bool loop = ref.watch(loopSurahProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.navyLine,
                  borderRadius: Radii.chip,
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('How would you like to listen?', style: AppType.titleLg),
            const SizedBox(height: Insets.xl),

            Text(
              'RECITER',
              style: AppType.label.copyWith(color: AppColors.mistFaint),
            ),
            const SizedBox(height: Insets.sm),
            for (final Reciter r in reciters)
              _Option(
                selected: r.id == reciter.id,
                title: r.name,
                subtitle: r.detail,
                onTap: () => ref.read(reciterProvider.notifier).set(r),
              ),
            const SizedBox(height: Insets.xl),

            Text(
              'PLAY',
              style: AppType.label.copyWith(color: AppColors.mistFaint),
            ),
            const SizedBox(height: Insets.sm),
            _Option(
              selected: mode == PlayMode.surah,
              title: 'The whole surah',
              subtitle: 'Straight through, each ayah once',
              onTap: () =>
                  ref.read(playModeProvider.notifier).set(PlayMode.surah),
            ),
            _Option(
              selected: mode == PlayMode.ayahByAyah,
              title: 'Ayah by ayah',
              subtitle: 'Each ayah $repeat× before the next — for memorising',
              onTap: () =>
                  ref.read(playModeProvider.notifier).set(PlayMode.ayahByAyah),
            ),
            if (mode == PlayMode.ayahByAyah) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(
                'REPEAT EACH AYAH',
                style: AppType.label.copyWith(color: AppColors.mistFaint),
              ),
              const SizedBox(height: Insets.sm),
              RepeatPicker(
                value: repeat,
                onChanged: (int n) {
                  unawaited(HapticFeedback.selectionClick());
                  unawaited(ref.read(ayahRepeatProvider.notifier).set(n));
                },
              ),
            ],
            const SizedBox(height: Insets.lg),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: loop,
              activeThumbColor: AppColors.gold,
              title: Text('Repeat the surah', style: AppType.titleSm),
              subtitle: Text(
                'Start again from the first ayah when it ends',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              onChanged: (bool v) =>
                  unawaited(ref.read(loopSurahProvider.notifier).set(v)),
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              label: 'Play',
              icon: Icons.play_arrow_rounded,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Keeps playing with the screen off. The lock screen has the '
              'same buttons; forward and back move by ayah.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(
                fontSize: 11,
                color: AppColors.mistFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.12)
            : AppColors.navyElevated,
        borderRadius: Radii.card,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.gold : AppColors.mistFaint,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppType.titleSm),
                      Text(
                        subtitle,
                        style: AppType.bodySm.copyWith(
                          fontSize: 12,
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
