import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/recitation_handler.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The transport every recitation shares: back, a big play, forward.
///
/// One set of buttons for the duas and the Qur'an, so the hand that learnt
/// one screen already knows the other.
class PlayerTransport extends StatelessWidget {
  const PlayerTransport({
    super.key,
    required this.playing,
    required this.onPlay,
    this.onPrevious,
    this.onNext,
    this.previousLabel = 'Previous',
    this.nextLabel = 'Next',
    this.compact = false,
  });

  final bool playing;
  final VoidCallback onPlay;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onNext;
  final String previousLabel;
  final String nextLabel;

  /// Smaller buttons, for a bar rather than a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        RoundControl(
          icon: Icons.skip_previous_rounded,
          tooltip: previousLabel,
          size: compact ? 40 : 46,
          onTap: onPrevious == null ? null : () => unawaited(onPrevious!()),
        ),
        SizedBox(width: compact ? Insets.md : Insets.lg),
        RoundControl(
          icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: playing ? 'Pause' : 'Play',
          size: compact ? 52 : 64,
          primary: true,
          onTap: onPlay,
        ),
        SizedBox(width: compact ? Insets.md : Insets.lg),
        RoundControl(
          icon: Icons.skip_next_rounded,
          tooltip: nextLabel,
          size: compact ? 40 : 46,
          onTap: onNext == null ? null : () => unawaited(onNext!()),
        ),
      ],
    );
  }
}

class RoundControl extends StatelessWidget {
  const RoundControl({
    super.key,
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
              size: primary ? size * 0.56 : size * 0.52,
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

/// Position within the current track, draggable.
class PlayerScrubber extends StatelessWidget {
  const PlayerScrubber({super.key, required this.handler});

  final RecitationHandler handler;

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
                    Text(clock(pos), style: _timeStyle),
                    Text(clock(length), style: _timeStyle),
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

  static String clock(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// 1× … 10×, one row of chips.
class RepeatPicker extends StatelessWidget {
  const RepeatPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (int n = min; n <= max; n++)
          Material(
            color: n == value
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.12),
            borderRadius: Radii.chip,
            child: InkWell(
              borderRadius: Radii.chip,
              onTap: () => onChanged(n),
              child: SizedBox(
                width: 40,
                height: 34,
                child: Center(
                  child: Text(
                    '$n×',
                    style: AppType.label.copyWith(
                      color: n == value ? AppColors.midnight : AppColors.cream,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
