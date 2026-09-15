import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/circle.dart';

/// Which day of its forty [circle] is on for [now], for a "Day 12 of 40":
/// 1 on the first day and never below it, so a circle made today reads as
/// day one rather than day nought.
int circleDayOn(Circle circle, DateTime now) =>
    circle.daysElapsed(now).clamp(1, circle.days);

/// How many days the members together have kept so far. Only members count:
/// somebody who left keeps their document, and it must not keep filling the
/// bar after they have gone.
int circleKept(Circle circle, Iterable<CircleProgress> progress) => progress
    .where((CircleProgress p) => circle.members.contains(p.uid))
    .fold<int>(0, (int sum, CircleProgress p) => sum + p.kept);

/// How many days everyone together could have kept by [now]: each member,
/// each day that has come round.
int circlePossible(Circle circle, DateTime now) =>
    circle.members.length * circle.daysElapsed(now);

/// The one bar a circle shares: a hairline track, filled in gold as far as
/// everyone together has come.
///
/// There is deliberately nothing per person on it — no segments, no marks
/// where each member stands. It is the circle's bar, not a race drawn on one.
class CircleBar extends StatelessWidget {
  const CircleBar({super.key, required this.fraction, this.height = 8});

  /// 0..1 — see [Circle.sharedFraction].
  final double fraction;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double f = fraction.clamp(0.0, 1.0);
    return Semantics(
      label: 'Kept together',
      value: '${(f * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ColoredBox(
                  color: AppColors.navyLine.withValues(alpha: 0.8),
                ),
              ),
              // Never invisible while there is anything at all to show: a
              // first day kept by one of six would otherwise round to nothing.
              if (f > 0)
                FractionallySizedBox(
                  widthFactor: f < 0.04 ? 0.04 : f,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: AppColors.goldSheen),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
