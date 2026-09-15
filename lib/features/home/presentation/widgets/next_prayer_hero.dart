import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/mihrab_arch.dart';
import '../../../../core/widgets/ticking_digits.dart';
import '../../../prayer_times/domain/prayer.dart';

/// The hero card from the widget reference: the live clock inside a glowing
/// mihrab, a countdown pill for the next prayer, and the neighbouring prayers
/// along the bottom.
class NextPrayerHero extends StatelessWidget {
  const NextPrayerHero({
    super.key,
    required this.now,
    required this.next,
    required this.nextIsTomorrow,
    required this.previous,
    required this.following,
    required this.locationLabel,
    this.use24h = false,
    this.onTap,
    this.onEarth = false,
  });

  final DateTime now;
  final PrayerSlot next;
  final bool nextIsTomorrow;

  /// The prayer whose window is running (shown bottom-left).
  final PrayerSlot? previous;

  /// The prayer after [next] (shown bottom-right).
  final PrayerSlot? following;
  final String locationLabel;
  final bool use24h;
  final VoidCallback? onTap;

  /// Drops the solid card so the globe behind shows through, and swaps in a
  /// scrim plus text shadows instead.
  ///
  /// The scrim is not decoration — it is what keeps the type readable. The
  /// Earth passing behind is sometimes ocean and sometimes bright city lights,
  /// so contrast cannot be left to whatever happens to rotate past.
  final bool onEarth;

  /// Enough to separate type from a lit coastline without looking embossed.
  static const List<Shadow> earthShadow = <Shadow>[
    Shadow(color: Color(0xE60A1020), blurRadius: 16),
    Shadow(color: Color(0x800A1020), blurRadius: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final PrayerPalette palette = next.id.palette;
    final Duration until = next.start.difference(now);

    // Over the Earth the backdrop is always dark, so the per-prayer ink cannot
    // be used: `onSurface` is a dark brown for Dhuhr and a dark navy for Asr —
    // inks picked to sit on a *light* card. On the globe they disappear
    // entirely, which is how Dhuhr rendered as brown-on-black.
    final Color ink = onEarth ? AppColors.cream : palette.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: onEarth
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    AppColors.midnight.withValues(alpha: 0.12),
                    AppColors.midnight.withValues(alpha: 0.46),
                    AppColors.midnight.withValues(alpha: 0.78),
                  ],
                  stops: const <double>[0, 0.45, 1],
                )
              : palette.gradient,
          borderRadius: BorderRadius.circular(Radii.xl),
          border: onEarth
              ? null
              : Border.all(color: AppColors.navyLine.withValues(alpha: 0.7)),
        ),
        child: Stack(
          children: <Widget>[
            // The glowing arch behind the clock. Dropped entirely over the
            // Earth: even at a tenth of its opacity its shoulder still cuts a
            // visible dome across the continents, and a soft shape with a
            // hard edge reads as a smudge on the planet rather than as light.
            if (!onEarth)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 46),
                  child: MihrabGlow(color: ink, opacity: 0.22, shoulder: 0.5),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              next.id.label,
                              style: AppType.displayMd
                                  .copyWith(color: ink)
                                  .lift(onEarth),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Begins ${Fmt.time(next.start, use24h: use24h)}'
                              '${nextIsTomorrow ? ' tomorrow' : ''}',
                              style: AppType.bodySm
                                  .copyWith(color: ink.withValues(alpha: 0.9))
                                  .lift(onEarth),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: ink.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                locationLabel,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: AppType.bodySm
                                    .copyWith(color: ink.withValues(alpha: 0.9))
                                    .lift(onEarth),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        TickingDigits(
                          value: Fmt.clock(now, use24h: use24h),
                          style: AppType.clock
                              .copyWith(color: ink)
                              .lift(onEarth),
                        ),
                        // Seconds ride below the baseline at a smaller size:
                        // the clock stays the hero, but the screen visibly
                        // ticks instead of looking frozen for a whole minute.
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: TickingDigits(
                            value: Fmt.seconds(now),
                            // Clearly readable, but still well under the 54pt
                            // clock — the seconds mark that time is moving,
                            // they are not the thing you read.
                            style: AppType.clockSuffix
                                .copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: ink.withValues(alpha: 0.85),
                                )
                                .lift(onEarth),
                          ),
                        ),
                        if (!use24h) ...<Widget>[
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Text(
                              Fmt.meridiem(now),
                              style: AppType.clockSuffix
                                  .copyWith(color: ink)
                                  .lift(onEarth),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.sm,
                      ),
                      decoration: BoxDecoration(
                        color: onEarth
                            ? AppColors.midnight.withValues(alpha: 0.42)
                            : ink.withValues(alpha: 0.16),
                        borderRadius: Radii.chip,
                        border: Border.all(color: ink.withValues(alpha: 0.24)),
                      ),
                      child: Text(
                        until.isNegative
                            ? '${next.id.label} has begun'
                            : '${next.id.label} in ${Fmt.countdown(until)}',
                        style: AppType.numeral
                            .copyWith(color: ink)
                            .lift(onEarth),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  Divider(color: ink.withValues(alpha: 0.18), height: 1),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Neighbour(
                          slot: previous,
                          palette: palette,
                          use24h: use24h,
                          alignment: CrossAxisAlignment.start,
                          caption: 'Now',
                          onEarth: onEarth,
                        ),
                      ),
                      Expanded(
                        child: _Neighbour(
                          slot: following,
                          palette: palette,
                          use24h: use24h,
                          alignment: CrossAxisAlignment.end,
                          caption: 'Then',
                          onEarth: onEarth,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Neighbour extends StatelessWidget {
  const _Neighbour({
    required this.slot,
    required this.palette,
    required this.use24h,
    required this.alignment,
    required this.caption,
    this.onEarth = false,
  });

  final PrayerSlot? slot;
  final PrayerPalette palette;
  final bool use24h;
  final CrossAxisAlignment alignment;
  final String caption;
  final bool onEarth;

  @override
  Widget build(BuildContext context) {
    if (slot == null) return const SizedBox.shrink();
    final Color ink = onEarth ? AppColors.cream : palette.onSurface;
    return Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          caption.toUpperCase(),
          style: AppType.label
              .copyWith(color: ink.withValues(alpha: 0.7))
              .lift(onEarth),
        ),
        const SizedBox(height: 3),
        Text(
          slot!.id.label,
          style: AppType.displaySm
              .copyWith(color: ink, fontSize: 17)
              .lift(onEarth),
        ),
        Text(
          Fmt.time(slot!.start, use24h: use24h),
          style: AppType.numeral
              .copyWith(fontSize: 15, color: ink.withValues(alpha: 0.88))
              .lift(onEarth),
        ),
      ],
    );
  }
}

/// Adds the lift shadow only in `onEarth` mode, so the flat card keeps its
/// clean type.
extension _Lift on TextStyle {
  TextStyle lift(bool on) =>
      on ? copyWith(shadows: NextPrayerHero.earthShadow) : this;
}
