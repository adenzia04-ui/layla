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
import 'download_row.dart';

/// The bar under a surah: who is reciting, which ayah, and the transport.
///
/// Play plays, with the remembered voice, mode and repeats. The gear opens
/// the options — whole surah or ayah by ayah, how many times each, which
/// voice, whether to loop — and is also where the surah is downloaded for
/// offline listening.
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
    );
    final Surah s = quran.surah(surah);
    final bool playing = now?.playing ?? false;

    // As the reciter moves, keep the next few recordings coming.
    ref.listen<AsyncValue<NowPlaying?>>(nowPlayingProvider, (
      AsyncValue<NowPlaying?>? _,
      AsyncValue<NowPlaying?> next,
    ) {
      final NowPlaying? n = surahNowPlaying(next.valueOrNull, surah);
      if (n == null) return;
      final int a = ayahOf(n);
      if (a > 0) prefetchAhead(ref, quran: quran, surah: surah, ayah: a);
    });

    Future<void> start() =>
        playSurah(ref, quran: quran, surah: surah, ayah: fromAyah);

    final String line = now == null
        ? s.name
        : ayahOf(now) == 0
        ? '${s.name} · whole surah'
        : 'Ayah ${ayahOf(now)} of ${s.ayahCount}'
              '${now.track.passes > 1 ? ' · ${now.pass}/${now.track.passes}' : ''}';

    // The same ground as the page, so the bar has no top edge: the text
    // above it fades out into midnight and the controls sit in it.
    return Material(
      color: AppColors.midnight,
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
                      line,
                      style: AppType.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      now == null
                          ? '${reciter.name} · tap play'
                          : now.loading
                          ? 'Loading…'
                          : now.track.subtitle,
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
                  // Play plays. The voice, mode and repeats are whatever
                  // was chosen last (or the defaults); the gear beside the
                  // transport is where they are changed.
                  if (now == null) {
                    await start();
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
                  final (String, PlayMode, int, bool) before =
                      listeningSettings(ref);
                  final bool go = await showPlayOptions(
                    context,
                    ref,
                    quran: quran,
                    surah: surah,
                  );
                  final bool changed = listeningSettings(ref) != before;
                  // A change while playing takes effect now, from this
                  // ayah — whether the sheet was closed with Play or just
                  // swiped away, because the screen's idea of "the
                  // recitation" follows the settings and would otherwise
                  // lose track of what is still sounding.
                  if (now != null && (go || changed)) {
                    final int a = ayahOf(now);
                    await playSurah(
                      ref,
                      quran: quran,
                      surah: surah,
                      ayah: a == 0 ? 1 : a,
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

/// Voice, mode, repeats, loop, download. Returns true when "Play" was
/// pressed.
Future<bool> showPlayOptions(
  BuildContext context,
  WidgetRef ref, {
  required Quran quran,
  required int surah,
}) async {
  final bool? go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.navy,
    isScrollControlled: true,
    // Never the whole screen: the strip above it is how the sheet is put
    // away without choosing, and a sheet with no way out is a trap.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) =>
        _PlayOptionsSheet(quran: quran, surah: surah),
  );
  return go ?? false;
}

class _PlayOptionsSheet extends ConsumerWidget {
  const _PlayOptionsSheet({required this.quran, required this.surah});

  final Quran quran;
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Reciter reciter = ref.watch(reciterProvider);
    final PlayMode mode = ref.watch(playModeProvider);
    final int repeat = ref.watch(ayahRepeatProvider);
    final bool loop = ref.watch(loopSurahProvider);
    // A whole-surah voice has nothing to repeat by ayah.
    final bool ayahTools = reciter.perAyah;

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
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'How would you like to listen?',
                    style: AppType.titleLg,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.mist),
                  child: const Text('Not now'),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            // Offline first: it is the one thing here that takes time.
            DownloadRow(quran: quran, surah: surah, reciter: reciter),
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
              selected: mode == PlayMode.surah || !ayahTools,
              title: 'The whole surah',
              subtitle: 'Straight through, each ayah once',
              onTap: () =>
                  ref.read(playModeProvider.notifier).set(PlayMode.surah),
            ),
            _Option(
              selected: mode == PlayMode.ayahByAyah && ayahTools,
              enabled: ayahTools,
              title: 'Ayah by ayah',
              subtitle: ayahTools
                  ? 'Each ayah $repeat× before the next — for memorising'
                  : '${reciter.name} is recorded as whole surahs only',
              onTap: () =>
                  ref.read(playModeProvider.notifier).set(PlayMode.ayahByAyah),
            ),
            if (mode == PlayMode.ayahByAyah && ayahTools) ...<Widget>[
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
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.12)
              : AppColors.navyElevated,
          borderRadius: Radii.card,
          child: InkWell(
            borderRadius: Radii.card,
            onTap: enabled ? onTap : null,
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
      ),
    );
  }
}
