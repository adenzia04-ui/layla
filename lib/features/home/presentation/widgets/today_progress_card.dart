import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/widgets/noor_flame.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../../streaks/domain/prayer_day.dart';

/// "Today's Progress — Fajr ✓ Dhuhr ✓ Asr ✓ Maghrib ○ Isha ○ · 7 days 🔥"
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({
    super.key,
    required this.day,
    required this.currentStreak,
    this.onReopen,
    this.choices,
    this.reopenable = const <PrayerId>{},
    this.onTap,
  });

  final PrayerDay day;
  final int currentStreak;
  final VoidCallback? onTap;

  /// Tapping a prayer to bring its choices back. Null hides the affordance
  /// entirely, so the card stays a read-only summary wherever it is reused.
  final void Function(PrayerId)? onReopen;

  /// Which prayers that tap applies to.
  ///
  /// Not just the missed ones. Saying "I will pray when I am home" leaves the
  /// prayer pending and hides its choices, and until now there was no way to
  /// bring them back — the answer that was meant to be the reversible one was
  /// the only one that could not be undone.
  final Set<PrayerId> reopenable;

  /// The prayer still waiting on an answer, if there is one.
  ///
  /// The choices live inside this card rather than in a banner above the
  /// prayer times, because this is already the part of the screen about what
  /// has and has not been prayed today. Asking the question anywhere else
  /// splits one subject across two places.
  final Widget? choices;

  @override
  Widget build(BuildContext context) {
    // No whole-card tap. It used to send the entire card to the streak
    // history, which meant reaching for a prayer pip — or, later, for one of
    // the three choices — navigated away instead. The card is a place to act,
    // not a link.
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Expanded rather than Spacer on these label/value rows. A Spacer
          // cannot go negative, so at 1.3x text on a narrow phone the two
          // labels together are wider than the card and the Row overflows —
          // silently, since release builds do not paint the stripes. Expanded
          // gives the heading somewhere to give way from.
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  "TODAY'S PROGRESS",
                  style: AppType.label.copyWith(color: AppColors.gold),
                ),
              ),
              // Nothing was owed on an excused day, so there is nothing to
              // count — and "0 of 5 confirmed" is the exact line a day of
              // missed prayers shows. Printing it over a pause would tell her
              // she had failed at something she was not asked to do, which is
              // the one thing this feature exists to prevent. Left blank
              // rather than reworded: the panel below already says the day is
              // paused, and a second label saying it again is a second thing
              // for a passer-by to read.
              if (!day.excused) ...<Widget>[
                const SizedBox(width: Insets.sm),
                Text(
                  '${day.completedCount} of ${PrayerId.obligatory.length} confirmed',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.lg),
          // Five beads on a string, the way the day's prayers are counted in
          // the hand: gold once confirmed, the string gold as far as the last
          // one, the next one breathing. Not five empty circles — those said
          // "nothing here yet", which is a poor greeting at dawn.
          _BeadStrand(day: day, reopenable: reopenable, onReopen: onReopen),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              const NoorFlame(size: 20, glow: false),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Current streak',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Text(
                currentStreak == 1 ? '1 day' : '$currentStreak days',
                style: AppType.titleMd.copyWith(color: AppColors.cream),
              ),
              if (onTap != null) ...<Widget>[
                const SizedBox(width: Insets.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.mistFaint,
                ),
              ],
            ],
          ),
          if (reopenable.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: AppColors.mistFaint,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tap a prayer above to answer it again.',
                    style: AppType.bodySm.copyWith(
                      fontSize: 11,
                      color: AppColors.mistFaint,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (choices != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            const Divider(height: 1, color: AppColors.navyLine),
            const SizedBox(height: Insets.lg),
            choices!,
          ],
        ],
      ),
    );
  }
}

class _BeadStrand extends StatefulWidget {
  const _BeadStrand({
    required this.day,
    required this.reopenable,
    required this.onReopen,
  });

  final PrayerDay day;
  final Set<PrayerId> reopenable;
  final void Function(PrayerId)? onReopen;

  @override
  State<_BeadStrand> createState() => _BeadStrandState();
}

class _BeadStrandState extends State<_BeadStrand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// The first prayer not yet dealt with — the one to breathe.
  PrayerId? get _next {
    for (final PrayerId id in PrayerId.obligatory) {
      if (widget.day.recordFor(id).status == PrayerStatus.pending) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final int done = widget.day.completedCount;
    final int n = PrayerId.obligatory.length;
    // The string is gold as far as the last confirmed bead.
    final double lit = done == 0 ? 0 : (done - 0.5) / n;
    return Stack(
      alignment: Alignment.topCenter,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: 17,
          child: CustomPaint(
            size: const Size(double.infinity, 8),
            painter: _StringPainter(lit: lit),
          ),
        ),
        Row(
          children: <Widget>[
            for (final PrayerId id in PrayerId.obligatory)
              Expanded(
                child: AnimatedBuilder(
                  animation: _breath,
                  builder: (BuildContext context, _) => _Bead(
                    id: id,
                    status: widget.day.recordFor(id).status,
                    breath: id == _next
                        ? Curves.easeInOut.transform(_breath.value)
                        : 0,
                    onTap: widget.reopenable.contains(id)
                        ? () => widget.onReopen?.call(id)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The string the beads hang on: sagging a little between them, gold as
/// far as the day has been prayed.
class _StringPainter extends CustomPainter {
  const _StringPainter({required this.lit});

  final double lit;

  Path _string(Size size) {
    final Path p = Path()..moveTo(size.width * 0.1, 0);
    p.quadraticBezierTo(size.width / 2, size.height, size.width * 0.9, 0);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _string(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.navyLine,
    );
    if (lit <= 0) return;
    for (final ui.PathMetric m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * lit),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = AppColors.gold.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(_StringPainter old) => old.lit != lit;
}

class _Bead extends StatelessWidget {
  const _Bead({
    required this.id,
    required this.status,
    required this.breath,
    this.onTap,
  });

  final PrayerId id;
  final PrayerStatus status;

  /// 0 for a bead at rest; rises and falls for the one that is next.
  final double breath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ({List<Color> fill, Color rim, IconData? mark, Color ink}) look =
        switch (status) {
          // Confirmed: the same navy bead, lit — a gold ring, the prayer's own
          // glyph in gold, and a soft glow. No tick; the light is the mark.
          PrayerStatus.completed => (
            fill: <Color>[
              AppColors.navyElevated,
              AppColors.navy,
              AppColors.midnight,
            ],
            rim: AppColors.gold,
            mark: null,
            ink: AppColors.goldSoft,
          ),
          PrayerStatus.missed => (
            fill: <Color>[
              const Color(0xFF7A3341),
              AppColors.rose.withValues(alpha: 0.55),
              const Color(0xFF3A1622),
            ],
            rim: AppColors.rose,
            mark: Icons.close_rounded,
            ink: AppColors.cream,
          ),
          PrayerStatus.awaitingProof => (
            fill: <Color>[
              AppColors.amber.withValues(alpha: 0.9),
              AppColors.amber.withValues(alpha: 0.55),
              const Color(0xFF5A3C12),
            ],
            rim: AppColors.amber,
            mark: Icons.photo_camera_outlined,
            ink: AppColors.midnight,
          ),
          // Covered by the prayer pause. A dash, not a cross: this prayer was
          // never owed, and the bead that says "missed" is the one thing this
          // day must not look like. Quiet enough, too, that five of them in a
          // row read as an unremarkable strand to anyone glancing over.
          PrayerStatus.excused => (
            fill: <Color>[
              AppColors.navyElevated,
              AppColors.navy,
              AppColors.midnight,
            ],
            rim: AppColors.navyLine,
            mark: Icons.remove_rounded,
            ink: AppColors.mistFaint,
          ),
          PrayerStatus.pending => (
            fill: <Color>[
              AppColors.navyElevated,
              AppColors.navy,
              AppColors.midnight,
            ],
            rim: AppColors.navyLine,
            mark: null,
            ink: AppColors.mistFaint,
          ),
        };
    final bool next = breath > 0;
    final double size = 34 + breath * 3;

    final Widget bead = Column(
      children: <Widget>[
        SizedBox(
          height: 40,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  colors: look.fill,
                  stops: const <double>[0, 0.55, 1],
                ),
                border: Border.all(
                  color: next
                      ? AppColors.gold.withValues(alpha: 0.5 + breath * 0.4)
                      : look.rim.withValues(
                          alpha: status == PrayerStatus.completed ? 0.95 : 0.7,
                        ),
                  width: next || status == PrayerStatus.completed ? 1.4 : 1,
                ),
                boxShadow: <BoxShadow>[
                  if (status == PrayerStatus.completed || next)
                    BoxShadow(
                      color: AppColors.gold.withValues(
                        alpha: status == PrayerStatus.completed
                            ? 0.35
                            : 0.15 + breath * 0.2,
                      ),
                      blurRadius: 14,
                    ),
                ],
              ),
              child: Center(
                child: look.mark != null
                    ? Icon(look.mark, size: 16, color: look.ink)
                    : Icon(
                        id.icon,
                        size: 14,
                        color: next
                            ? AppColors.gold.withValues(
                                alpha: 0.6 + breath * 0.4,
                              )
                            : look.ink,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          id.label,
          style: AppType.bodySm.copyWith(
            fontSize: 11,
            // Excused dims with pending. The bead body is already quiet, but
            // the label under it is the part someone glancing at the phone
            // actually reads — at full mist five of them in a row made a
            // paused day the loudest version of this row rather than the least
            // remarkable. (`next` is never true on an excused day: no record
            // there is pending.)
            color:
                (status == PrayerStatus.pending ||
                        status == PrayerStatus.excused) &&
                    !next
                ? AppColors.mistFaint
                : AppColors.mist,
          ),
        ),
      ],
    );

    if (onTap == null) return bead;
    return Semantics(
      button: true,
      label: 'Reopen ${id.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: bead,
      ),
    );
  }
}
