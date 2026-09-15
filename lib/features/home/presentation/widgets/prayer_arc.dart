import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../prayer_times/domain/prayer.dart';
import '../../../streaks/domain/prayer_day.dart';

/// The day as the sun's path: an arc from Fajr on the left to Isha on the
/// right, the six moments set along it where they fall in the day, and a
/// light for where the day is now.
///
/// Replaces six boxes. Boxes said "here are six numbers"; the arc says where
/// you are in the day, which is what someone glancing at prayer times is
/// really asking. Sunrise is on the path because it bounds Fajr, but it is
/// not a prayer: it never takes the light and carries no confirmation.
class PrayerArc extends StatefulWidget {
  const PrayerArc({
    super.key,
    required this.schedule,
    required this.now,
    required this.day,
    this.use24h = false,
    this.onTapPrayer,
  });

  final PrayerSchedule schedule;
  final DateTime now;
  final PrayerDay day;
  final bool use24h;
  final ValueChanged<PrayerId>? onTapPrayer;

  static const List<PrayerId> order = <PrayerId>[
    PrayerId.fajr,
    PrayerId.sunrise,
    PrayerId.dhuhr,
    PrayerId.asr,
    PrayerId.maghrib,
    PrayerId.isha,
  ];

  @override
  State<PrayerArc> createState() => _PrayerArcState();
}

class _PrayerArcState extends State<PrayerArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  /// 0 at Fajr, 1 at Isha, for a moment in the day.
  double _along(DateTime t) {
    final DateTime a = widget.schedule.slotFor(PrayerId.fajr).start;
    final DateTime b = widget.schedule.slotFor(PrayerId.isha).start;
    final int span = b.difference(a).inSeconds;
    if (span <= 0) return 0;
    return (t.difference(a).inSeconds / span).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final PrayerSlot? active = widget.schedule.currentAt(widget.now);
    final List<double> marks = <double>[
      for (final PrayerId id in PrayerArc.order)
        _along(widget.schedule.slotFor(id).start),
    ];
    final double nowAt = _along(widget.now);
    final bool night =
        widget.now.isBefore(widget.schedule.slotFor(PrayerId.fajr).start) ||
        widget.now.isAfter(widget.schedule.slotFor(PrayerId.isha).start);

    return Column(
      children: <Widget>[
        SizedBox(
          height: 96,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (BuildContext context, _) => CustomPaint(
              size: Size.infinite,
              painter: _ArcPainter(
                marks: marks,
                nowAt: nowAt,
                night: night,
                activeIndex: active == null
                    ? -1
                    : PrayerArc.order.indexOf(active.id),
                breath: Curves.easeInOut.transform(_breath.value),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.sm),
        Row(
          children: <Widget>[
            for (final PrayerId id in PrayerArc.order)
              Expanded(
                child: _Moment(
                  id: id,
                  time: Fmt.clock(
                    widget.schedule.slotFor(id).start,
                    use24h: widget.use24h,
                  ),
                  isActive: id.isObligatory && active?.id == id,
                  status: id.isObligatory
                      ? widget.day.recordFor(id).status
                      : null,
                  onTap: widget.onTapPrayer == null
                      ? null
                      : () => widget.onTapPrayer!(id),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The path, the six marks on it, and the light where the day is.
class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.marks,
    required this.nowAt,
    required this.night,
    required this.activeIndex,
    required this.breath,
  });

  final List<double> marks;
  final double nowAt;
  final bool night;
  final int activeIndex;
  final double breath;

  /// A point on the arc for a share of the day. The arc is one quadratic
  /// curve from the left foot up through the top and down to the right.
  Offset _at(double t, Size size) {
    final Offset p0 = Offset(size.width * 0.08, size.height - 10);
    final Offset p1 = Offset(size.width / 2, -size.height * 0.55);
    final Offset p2 = Offset(size.width * 0.92, size.height - 10);
    final double u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The path itself: faint, dashed, the way a sun's course is drawn.
    final Path path = Path();
    for (int i = 0; i <= 60; i++) {
      final Offset p = _at(i / 60, size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.navyLine;
    _dash(canvas, path, track);

    // The part of the day already walked, solid and gold.
    final Path done = Path();
    for (int i = 0; i <= 60; i++) {
      final double t = (i / 60) * nowAt;
      final Offset p = _at(t, size);
      if (i == 0) {
        done.moveTo(p.dx, p.dy);
      } else {
        done.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      done,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(alpha: night ? 0.35 : 0.8),
    );

    // The horizon line the arc rises from.
    canvas.drawLine(
      Offset(0, size.height - 10),
      Offset(size.width, size.height - 10),
      Paint()
        ..strokeWidth = 0.7
        ..color = AppColors.navyLine.withValues(alpha: 0.7),
    );

    // Six marks: small stars on the path, the running prayer's lit.
    for (int i = 0; i < marks.length; i++) {
      final Offset c = _at(marks[i], size);
      final bool lit = i == activeIndex;
      final Color color = lit ? AppColors.gold : AppColors.mist;
      canvas.drawCircle(
        c,
        lit ? 4.5 : 3,
        Paint()..color = color.withValues(alpha: lit ? 1 : 0.8),
      );
      canvas.drawCircle(
        c,
        lit ? 8 : 5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: lit ? 0.55 : 0.25),
      );
    }

    // Where the day is now: the sun by day, the moon by night, breathing.
    final Offset now = _at(nowAt, size);
    final Color light = night ? AppColors.goldSoft : AppColors.gold;
    canvas.drawCircle(
      now,
      14 + breath * 4,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            light.withValues(alpha: 0.5),
            light.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: now, radius: 18)),
    );
    if (night) {
      // A crescent: a disc with a second, offset disc cut out of it.
      final Path moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: now, radius: 6.5)),
        Path()..addOval(
          Rect.fromCircle(center: now + const Offset(2.8, -1.1), radius: 5.6),
        ),
      );
      canvas.drawPath(moon, Paint()..color = AppColors.goldSoft);
    } else {
      canvas.drawCircle(now, 6.5, Paint()..color = AppColors.gold);
      canvas.drawCircle(
        now,
        4,
        Paint()..color = AppColors.goldSoft.withValues(alpha: 0.9),
      );
    }
  }

  /// Draws [path] as short dashes.
  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final ui.PathMetric metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final double end = math.min(d + 4, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.nowAt != nowAt ||
      old.breath != breath ||
      old.activeIndex != activeIndex ||
      old.night != night;
}

/// One of the six, under its place on the arc: the name in small capitals
/// and the time beneath, the running one in gold. No box.
class _Moment extends StatelessWidget {
  const _Moment({
    required this.id,
    required this.time,
    required this.isActive,
    required this.status,
    this.onTap,
  });

  final PrayerId id;
  final String time;
  final bool isActive;
  final PrayerStatus? status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color name = isActive ? AppColors.gold : AppColors.mistFaint;
    final Color clock = isActive ? AppColors.cream : AppColors.mist;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            Text(
              id.label.toUpperCase(),
              style: AppType.label.copyWith(fontSize: 9, color: name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            FittedBox(
              child: Text(
                time,
                style: AppType.numeral.copyWith(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: clock,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _Mark(status: status),
          ],
        ),
      ),
    );
  }
}

/// A tiny mark of what happened: a tick, a cross, a camera, or nothing.
class _Mark extends StatelessWidget {
  const _Mark({required this.status});

  final PrayerStatus? status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      // A confirmed prayer is shown once, as the lit bead in Today's
      // Progress; a second tick under the time only doubled it.
      PrayerStatus.missed => const Icon(
        Icons.close_rounded,
        size: 12,
        color: AppColors.rose,
      ),
      PrayerStatus.awaitingProof => const Icon(
        Icons.photo_camera_outlined,
        size: 11,
        color: AppColors.amber,
      ),
      _ => const SizedBox(height: 12),
    };
  }
}
