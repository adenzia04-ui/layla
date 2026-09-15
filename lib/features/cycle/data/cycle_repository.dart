import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../streaks/data/prayer_day_repository.dart';
import '../../streaks/domain/prayer_day.dart';
import '../domain/cycle.dart';

final Provider<CycleRepository> cycleRepositoryProvider =
    Provider<CycleRepository>(
      (Ref ref) => CycleRepository(
        ref.watch(firestoreProvider),
        ref.watch(authRepositoryProvider),
        ref.watch(prayerDayRepositoryProvider),
      ),
    );

/// Starts, ends and back-fills the prayer pause.
///
/// Two documents and nothing else: `users/{uid}.cycle` says whether a pause is
/// on, and `users/{uid}/prayer_days/{date}.excused` marks each day it covers.
/// Both are owner-only under `firestore.rules`, and that is deliberate — see
/// [Cycle]. Nothing in this file writes anywhere a friend can read, and
/// nothing here may ever be allowed to.
class CycleRepository {
  const CycleRepository(this._db, this._auth, this._days);

  final FirebaseFirestore _db;
  final AuthRepository _auth;
  final PrayerDayRepository _days;

  CollectionReference<Map<String, Object?>> _dayDocs(String uid) =>
      _db.collection('users').doc(uid).collection('prayer_days');

  /// Begins a pause today, and marks today excused.
  ///
  /// Idempotent in the way that matters: pressing it twice writes today's
  /// start day twice and changes nothing.
  Future<void> start({DateTime? now}) async {
    final String uid = _requireUid();
    final String today = Fmt.dayId(now ?? DateTime.now());

    await _auth.userDoc(uid).set(<String, Object?>{
      'cycle': Cycle(startedOn: today).toMap(),
    }, SetOptions(merge: true));

    await _days.markExcused(dateId: today);
  }

  /// Ends the pause.
  ///
  /// Only ever called because she said so. Nothing in this app decides on her
  /// behalf that a pause has ended — it ends when the bleeding stops and she
  /// has performed ghusl, and the app cannot know that.
  ///
  /// Days already marked excused stay excused. They were not prayed and are
  /// not owed, and rewriting history to say otherwise would be the one thing
  /// this feature exists to avoid. Everything else — the reminders, the nudge,
  /// the lock, the choices on Home — comes back on its own from the next
  /// prayer whose time is in, because all of them read the pause rather than
  /// hold state of their own.
  Future<void> end() async {
    final String uid = _requireUid();
    // Null rather than a deleted key: `firestore.rules` accepts either, and
    // null is the value the reading code already treats as "no pause".
    await _auth.userDoc(uid).set(<String, Object?>{
      'cycle': null,
    }, SetOptions(merge: true));
  }

  /// Marks every day of the pause that still needs it, at app open.
  ///
  /// The app cannot rely on being open at midnight, so a pause that began on
  /// Monday and is looked at on Thursday has three days nobody has recorded.
  /// Left unrecorded they are three days with no record at all, which is
  /// exactly what a broken streak looks like to `UserStats.streakOn`.
  ///
  /// Idempotent by construction: it asks Firestore which of the covered days
  /// already exist, skips the ones already excused or already finished, and
  /// leans on [PrayerDayRepository.markExcused] — which writes nothing when
  /// there is nothing to change — for the rest. Ten app opens in one day cost
  /// one query and no writes, and the streak does not move.
  Future<void> catchUp({required Cycle cycle, DateTime? now}) async {
    final String? uid = _auth.uid;
    if (uid == null || !cycle.isActive) return;

    final List<String> covered = CycleDays.covered(
      cycle.startedOn,
      now ?? DateTime.now(),
    );
    if (covered.isEmpty) return;

    // One range query rather than a read per day: the ids are the dates, so
    // Firestore serves the whole stretch in document-id order for free.
    final QuerySnapshot<Map<String, Object?>> existing = await _dayDocs(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: covered.first)
        .where(FieldPath.documentId, isLessThanOrEqualTo: covered.last)
        .get();

    final Set<String> alreadyExcused = <String>{};
    final Set<String> alreadyComplete = <String>{};
    for (final QueryDocumentSnapshot<Map<String, Object?>> doc
        in existing.docs) {
      final PrayerDay day = PrayerDay.fromDoc(doc);
      if (day.excused) alreadyExcused.add(doc.id);
      if (day.isComplete) alreadyComplete.add(doc.id);
    }

    final List<String> todo = CycleDays.needingMark(
      startedOn: cycle.startedOn,
      today: now ?? DateTime.now(),
      alreadyExcused: alreadyExcused,
      alreadyComplete: alreadyComplete,
    );

    // In order, oldest first, so `lastCompletedDate` only ever moves forward.
    for (final String dateId in todo) {
      await _days.markExcused(dateId: dateId);
    }
  }

  String _requireUid() {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('You need to be signed in to do that.');
    }
    return uid;
  }
}
