import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';
import '../../friends/domain/friend.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/domain/prayer_day.dart';

/// What a circle holds each other to.
///
/// Three, deliberately coarse. Each is a yes-or-no per day that a phone can
/// answer from its own day document, so a member's count is theirs alone to
/// compute and nothing about any day — least of all a paused one — has to be
/// shared to compute it.
enum CircleGoal {
  fajr,
  five,
  tahajjud;

  /// The stored form, which `firestore.rules` holds to exactly these three.
  String get key => name;

  String get label => switch (this) {
    CircleGoal.fajr => 'Fajr, every day',
    CircleGoal.five => 'All five, every day',
    CircleGoal.tahajjud => 'Tahajjud, every night',
  };

  static CircleGoal? fromKey(String? key) {
    for (final CircleGoal value in values) {
      if (value.key == key) return value;
    }
    return null;
  }

  /// Whether [day] kept this goal.
  ///
  /// Never on a day the prayer pause covers. Those days are not kept and not
  /// missed — they do not count either way — and a count is the only thing
  /// that ever leaves the phone, so an excused day simply adds nothing to
  /// it, exactly as a day with no record does. Nothing here is written
  /// anywhere; this is read off the owner's own documents and folded into a
  /// number.
  bool keptOn(PrayerDay day) {
    if (day.excused) return false;
    return switch (this) {
      CircleGoal.fajr => day.recordFor(PrayerId.fajr).isCompleted,
      CircleGoal.five => day.isComplete,
      CircleGoal.tahajjud => day.tahajjudPrayed,
    };
  }
}

/// A shared forty days: `circles/{circleId}`.
///
/// A few people, one goal, a start date and a code. Each member's own phone
/// counts the days it kept and publishes that one number; the circle shows
/// the numbers side by side and one bar for all of them. There is no ranking
/// and nothing that could be turned into one — see [CircleProgress].
@immutable
class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.goal,
    required this.startsOn,
    required this.code,
    required this.createdBy,
    required this.members,
    this.days = length,
    this.createdAt,
  });

  /// How long a circle runs. Forty, because forty days is the span the
  /// tradition gives a habit, and because the rules pin `days` to it.
  static const int length = 40;

  /// The most people a circle holds; the rules refuse a twenty-first.
  static const int maxMembers = 20;

  final String id;
  final String name;
  final CircleGoal goal;

  /// "2026-09-15" — the first day that counts.
  final String startsOn;

  /// How many days it runs; always [length] for a circle this app made.
  final int days;

  /// The six-character code that joins it, the same shape as a friend code.
  final String code;
  final String createdBy;
  final List<String> members;

  /// Server time of creation. Null for the instant before it is stamped.
  final DateTime? createdAt;

  /// "2026-10-24" — the last day that counts.
  String get endsOn {
    final DateTime? start = Fmt.parseDayId(startsOn);
    if (start == null) return startsOn;
    return Fmt.dayId(start.add(Duration(days: days - 1)));
  }

  /// How many of the days have come round by [today], 0 to [days]. The
  /// denominator of the shared bar, once multiplied by the members.
  int daysElapsed(DateTime today) {
    final int? elapsed = Fmt.daysBetweenDayIds(startsOn, Fmt.dayId(today));
    if (elapsed == null || elapsed < 0) return 0;
    return (elapsed + 1).clamp(0, days);
  }

  /// Whether the last day has passed.
  bool isOver(DateTime today) => Fmt.dayId(today).compareTo(endsOn) > 0;

  /// How many of the days up to [today] the owner of [prayerDays] kept.
  ///
  /// Only days inside the circle's span count, and only up to today —
  /// tomorrow's document does not exist yet, but a phone with its clock wrong
  /// could have written one. Each day counts at most once whatever the list
  /// holds, and the answer never exceeds [days].
  int keptOn(Iterable<PrayerDay> prayerDays, DateTime today) {
    final String todayId = Fmt.dayId(today);
    final String last = todayId.compareTo(endsOn) < 0 ? todayId : endsOn;
    final Set<String> kept = <String>{};
    for (final PrayerDay day in prayerDays) {
      if (day.dateId.compareTo(startsOn) < 0) continue;
      if (day.dateId.compareTo(last) > 0) continue;
      if (goal.keptOn(day)) kept.add(day.dateId);
    }
    return kept.length.clamp(0, days);
  }

  /// The shared bar, 0 to 1: every kept day across the circle over every day
  /// that has come round for every member. Zero before the first day.
  double sharedFraction(Iterable<CircleProgress> progress, DateTime today) {
    final int possible = members.length * daysElapsed(today);
    if (possible <= 0) return 0;
    int kept = 0;
    for (final CircleProgress p in progress) {
      if (members.contains(p.uid)) kept += p.kept;
    }
    return (kept / possible).clamp(0.0, 1.0);
  }

  /// The stored document read back, or null when it is not one this app
  /// could have written — a goal from a newer build, a start that is not a
  /// day id. Tested rather than cast: the document is shared, and a throw
  /// here would take every circle in the list down with it.
  static Circle? fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Object? goal = data['goal'];
    final Object? startsOn = data['startsOn'];
    final Object? code = data['code'];
    final Object? createdBy = data['createdBy'];
    final Object? members = data['members'];
    final Object? days = data['days'];
    final Object? createdAt = data['createdAt'];
    final CircleGoal? parsedGoal = CircleGoal.fromKey(
      goal is String ? goal : null,
    );
    if (parsedGoal == null) return null;
    if (startsOn is! String || Fmt.parseDayId(startsOn) == null) return null;
    if (createdBy is! String || createdBy.isEmpty) return null;
    return Circle(
      id: doc.id,
      name: FriendName.clean(
        data['name'] is String ? data['name'] as String : null,
      ),
      goal: parsedGoal,
      startsOn: startsOn,
      days: days is num && days.toInt() > 0 ? days.toInt() : length,
      code: code is String ? FriendCode.normalize(code) : '',
      createdBy: createdBy,
      members: <String>[
        if (members is List<Object?>)
          for (final Object? member in members)
            if (member is String && member.isNotEmpty) member,
      ],
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
    );
  }

  /// The document as created, in exactly the shape the rules take: the
  /// creator as the only member, forty days, and the server's clock.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'goal': goal.key,
    'startsOn': startsOn,
    'days': days,
    'code': code,
    'createdBy': createdBy,
    'members': members,
    'createdAt': createdAt == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt!),
  };

  @override
  bool operator ==(Object other) =>
      other is Circle &&
      other.id == id &&
      other.name == name &&
      other.goal == goal &&
      other.startsOn == startsOn &&
      other.days == days &&
      other.code == code &&
      other.createdBy == createdBy &&
      listEquals(other.members, members) &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    goal,
    startsOn,
    days,
    code,
    createdBy,
    Object.hashAll(members),
    createdAt,
  );

  @override
  String toString() => 'Circle($id "$name" ${goal.key} from $startsOn)';
}

/// One member's count: `circles/{circleId}/progress/{uid}`.
///
/// A single number, computed by that member's own phone from its own day
/// documents and written by nobody else. It is the whole of what a circle
/// knows about anybody's days: not which days, not why a day was not kept,
/// and nothing whatsoever about the prayer pause.
@immutable
class CircleProgress {
  const CircleProgress({required this.uid, required this.kept, this.updatedAt});

  final String uid;

  /// Days kept so far, 0 to [Circle.length].
  final int kept;

  /// Server time of the last publish. Null for the instant before it lands.
  final DateTime? updatedAt;

  factory CircleProgress.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Object? kept = data['kept'];
    final Object? updatedAt = data['updatedAt'];
    return CircleProgress(
      uid: doc.id,
      kept: (kept is num ? kept.toInt() : 0).clamp(0, Circle.length),
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  /// The document as written; the server stamps `updatedAt`.
  Map<String, Object?> toMap() => <String, Object?>{
    'kept': kept,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  bool operator ==(Object other) =>
      other is CircleProgress &&
      other.uid == uid &&
      other.kept == kept &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(uid, kept, updatedAt);
}

/// Why joining a circle by code did not go through.
enum CircleJoinError {
  invalidCode,
  notFound,
  already,
  notSignedIn,
  guest,

  /// The rules would not have it: the circle is full, or the code has gone.
  refused;

  /// What to tell the person, in the app's voice.
  String get message => switch (this) {
    CircleJoinError.invalidCode =>
      'A circle code is six letters and numbers, like ABC-234.',
    CircleJoinError.notFound =>
      'No circle has that code. Check it with whoever shared it.',
    CircleJoinError.already => 'You are already in that circle.',
    CircleJoinError.notSignedIn => 'Sign in to join a circle.',
    CircleJoinError.guest =>
      'Circles need a full account. Add an email and password from your '
          'profile and keep your streak.',
    CircleJoinError.refused =>
      'Layla Pro could not join that circle. It may already have twenty '
          'people in it.',
  };
}

class CircleJoinException implements Exception {
  const CircleJoinException(this.error);

  final CircleJoinError error;

  String get message => error.message;

  @override
  String toString() => message;
}
