import 'package:flutter/material.dart';

import '../../domain/circle.dart';

/// How each goal is drawn where a circle is chosen or shown: the short name
/// on a chooser tile, the line under it, and the glyph. The full sentence a
/// circle is described with is [CircleGoal.label], on the domain.
extension CircleGoalLook on CircleGoal {
  /// The name on a create-sheet tile, short enough for a third of a small
  /// phone: "Fajr on time".
  String get tileLabel => switch (this) {
    CircleGoal.fajr => 'Fajr on time',
    CircleGoal.five => 'All five',
    CircleGoal.tahajjud => 'Tahajjud',
  };

  /// The line under the chooser: what counts as a kept day.
  String get hint => switch (this) {
    CircleGoal.fajr => 'A day counts when Fajr is confirmed.',
    CircleGoal.five => 'A day counts when all five are confirmed.',
    CircleGoal.tahajjud => 'A night counts when Tahajjud is prayed.',
  };

  IconData get icon => switch (this) {
    CircleGoal.fajr => Icons.wb_twilight_rounded,
    CircleGoal.five => Icons.check_circle_outline_rounded,
    CircleGoal.tahajjud => Icons.bedtime_outlined,
  };
}
