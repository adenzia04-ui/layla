import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../application/dua_audio_handler.dart';
import '../../application/dua_player.dart';
import '../../domain/dua_text.dart';

/// Listen to a dua, and to the ones after it.
///
/// One card under the text: play, back, forward, a scrubber, and the repeat
/// count. Play reads this dua the chosen number of times, then goes on
/// through the section, and keeps going with the screen off — the lock
/// screen carries the same buttons. Someone learning the dua after wudu
/// should be able to put the phone down and say it along with the reciter.
class DuaPlayerCard extends ConsumerWidget {
  const DuaPlayerCard({
    super.key,
    required this.dua,
    required this.section,
    required this.heading,
  });

  final DuaText dua;
  final DuaTextSection section;
  final String heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DuaAudioHandler? handler = ref.watch(duaAudioHandlerProvider);
    if (handler == null || !dua.hasArabic) return const SizedBox.shrink();

    final DuaNowPlaying? now = ref.watch(duaNowPlayingProvider).valueOrNull;
    final bool mine = now != null && now.item.number == dua.number;
    final bool playing = mine && now.playing;
    final int repeat = ref.watch(duaRepeatProvider);

    Future<void> start() => handler.playSection(
      duas: section.duas,
      heading: heading,
      startNumber: dua.number,
      repeat: repeat,
    );

    return NightCard(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.lg,
        Insets.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.headphones_rounded,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  mine
                      ? (now.item.passes > 1
                            ? 'Reading ${now.item.pass} of ${now.item.passes}'
                            : 'Reading')
                      : 'Listen',
                  style: AppType.titleSm,
                ),
              ),
              Text(
                'Keeps playing with the screen off',
                style: AppType.bodySm.copyWith(
                  fontSize: 11,
                  color: AppColors.mistFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // The scrubber only means something for the dua on screen.
          if (mine) _Scrubber(handler: handler),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _Round(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Previous dua',
                onTap: mine ? handler.skipToPrevious : null,
              ),
              const SizedBox(width: Insets.lg),
              _Round(
                icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                tooltip: playing ? 'Pause' : 'Play',
                size: 64,
                primary: true,
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!mine) {
                    unawaited(start());
                  } else if (playing) {
                    unawaited(handler.pause());
                  } else {
                    unawaited(handler.play());
                  }
                },
              ),
              const SizedBox(width: Insets.lg),
              _Round(
                icon: Icons.skip_next_rounded,
                tooltip: 'Next dua',
                onTap: mine ? handler.skipToNext : null,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),

          Text(
            'REPEAT EACH DUA',
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int n = DuaRepeat.min; n <= DuaRepeat.max; n++)
                _Count(
                  n: n,
                  selected: n == repeat,
                  onTap: () async {
                    unawaited(HapticFeedback.selectionClick());
                    await ref.read(duaRepeatProvider.notifier).set(n);
                    // A change while this dua is playing takes effect now,
                    // from the start of this dua, rather than on the next
                    // section — otherwise the chips look broken.
                    if (mine) await start();
                  },
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            repeat == 1
                ? 'Each dua is read once, then the next one follows.'
                : 'Each dua is read $repeat times before the next one.',
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

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.handler});

  final DuaAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: handler.duration,
      builder: (BuildContext context, AsyncSnapshot<Duration?> total) {
        final Duration length = total.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: handler.position,
          builder: (BuildContext context, AsyncSnapshot<Duration> at) {
            final Duration pos = at.data ?? Duration.zero;
            final double max = length.inMilliseconds.toDouble();
            final double value = max == 0
                ? 0
                : pos.inMilliseconds.clamp(0, length.inMilliseconds).toDouble();
            return Column(
              children: <Widget>[
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: AppColors.gold,
                    inactiveTrackColor: AppColors.gold.withValues(alpha: 0.2),
                    thumbColor: AppColors.gold,
                  ),
                  child: Slider(
                    value: value,
                    max: max == 0 ? 1 : max,
                    onChanged: max == 0
                        ? null
                        : (double v) => unawaited(
                            handler.seek(Duration(milliseconds: v.round())),
                          ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(_clock(pos), style: _timeStyle),
                    Text(_clock(length), style: _timeStyle),
                  ],
                ),
                const SizedBox(height: Insets.sm),
              ],
            );
          },
        );
      },
    );
  }

  static final TextStyle _timeStyle = AppType.bodySm.copyWith(
    fontSize: 11,
    color: AppColors.mistFaint,
  );

  static String _clock(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 46,
    this.primary = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary
            ? AppColors.gold
            : AppColors.gold.withValues(alpha: enabled ? 0.16 : 0.07),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: primary ? 36 : 24,
              color: primary
                  ? AppColors.midnight
                  : AppColors.cream.withValues(alpha: enabled ? 1 : 0.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.n, required this.selected, required this.onTap});

  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : AppColors.gold.withValues(alpha: 0.12),
      borderRadius: Radii.chip,
      child: InkWell(
        borderRadius: Radii.chip,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 34,
          child: Center(
            child: Text(
              '$n×',
              style: AppType.label.copyWith(
                color: selected ? AppColors.midnight : AppColors.cream,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
