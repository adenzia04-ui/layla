import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/recitation_handler.dart';
import '../../../../core/audio/recitation_player.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/player_controls.dart';
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
    final RecitationHandler? handler = ref.watch(recitationHandlerProvider);
    if (handler == null || !dua.hasArabic) return const SizedBox.shrink();

    final NowPlaying? now = duaNowPlaying(
      ref.watch(nowPlayingProvider).valueOrNull,
      section,
    );
    final bool mine = now != null && now.track.group == '${dua.number}';
    final bool playing = mine && now.playing;
    final int repeat = ref.watch(duaRepeatProvider);

    Future<void> start() => playDuaSection(
      ref,
      section: section,
      heading: heading,
      startNumber: dua.number,
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
                      ? (now.track.passes > 1
                            ? 'Reading ${now.pass} of ${now.track.passes}'
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
          if (mine) PlayerScrubber(handler: handler),

          PlayerTransport(
            playing: playing,
            onPlay: () {
              unawaited(HapticFeedback.lightImpact());
              if (!mine) {
                unawaited(start());
              } else if (playing) {
                unawaited(handler.pause());
              } else {
                unawaited(handler.play());
              }
            },
            onPrevious: mine ? handler.skipToPrevious : null,
            onNext: mine ? handler.skipToNext : null,
            previousLabel: 'Previous dua',
            nextLabel: 'Next dua',
          ),
          const SizedBox(height: Insets.lg),

          Text(
            'REPEAT EACH DUA',
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.sm),
          RepeatPicker(
            value: repeat,
            min: DuaRepeat.min,
            max: DuaRepeat.max,
            onChanged: (int n) async {
              unawaited(HapticFeedback.selectionClick());
              await ref.read(duaRepeatProvider.notifier).set(n);
              // A change while this dua is playing takes effect now, from
              // the start of this dua, rather than on the next section —
              // otherwise the chips look broken.
              if (mine) await start();
            },
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
