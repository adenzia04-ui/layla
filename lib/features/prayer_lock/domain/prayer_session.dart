import 'package:flutter/foundation.dart';

import '../../prayer_times/domain/prayer.dart';
import '../../streaks/domain/prayer_day.dart';

/// How long the focus window stays open after a prayer begins.
const Duration kPrayerSessionLength = Duration(minutes: 30);

/// The live state of a prayer's 30-minute window.
@immutable
class PrayerSession {
  const PrayerSession({
    required this.prayer,
    required this.startedAt,
    required this.endsAt,
    required this.status,
  });

  final PrayerId prayer;

  /// When the prayer's time began.
  final DateTime startedAt;

  /// [startedAt] + 30 minutes.
  final DateTime endsAt;
  final PrayerStatus status;

  Duration remaining(DateTime now) {
    final Duration left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  double progress(DateTime now) {
    final double elapsed =
        now.difference(startedAt).inSeconds / kPrayerSessionLength.inSeconds;
    return elapsed.clamp(0, 1);
  }

  bool isOpenAt(DateTime now) =>
      !now.isBefore(startedAt) && now.isBefore(endsAt);

  /// The 30 minutes have run out and the prayer is still unconfirmed.
  ///
  /// The session does **not** end here. Blocked apps stay blocked until both
  /// confirmation steps are done — the window is a target, not a deadline.
  bool isOverdueAt(DateTime now) => !now.isBefore(endsAt);

  /// True once Step 1 is done and the photo is still outstanding. While this
  /// holds, the prayer is **not** counted and the focus screen stays reachable.
  bool get awaitingProof => status == PrayerStatus.awaitingProof;

  bool get isConfirmed => status == PrayerStatus.completed;

  @override
  bool operator ==(Object other) =>
      other is PrayerSession &&
      other.prayer == prayer &&
      other.startedAt == startedAt &&
      other.status == status;

  @override
  int get hashCode => Object.hash(prayer, startedAt, status);
}
