import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../domain/prayer_day.dart';

final Provider<PrayerDayRepository> prayerDayRepositoryProvider =
    Provider<PrayerDayRepository>(
  (Ref ref) => PrayerDayRepository(
    ref.watch(firestoreProvider),
    ref.watch(authRepositoryProvider),
  ),
);

/// Reads and writes `users/{uid}/prayer_days/{yyyy-MM-dd}`, and keeps the
/// user's streak counters in step.
///
/// The same arithmetic runs in the `recalculateStreak` Cloud Function, which
/// is authoritative; the client writes are optimistic so the UI reacts
/// instantly and still converges if a device clock is wrong.
class PrayerDayRepository {
  const PrayerDayRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final AuthRepository _auth;

  CollectionReference<Map<String, Object?>> _days(String uid) =>
      _db.collection('users').doc(uid).collection('prayer_days');

  Stream<PrayerDay> watchDay(String dateId) {
    final String? uid = _auth.uid;
    if (uid == null) return Stream<PrayerDay>.value(PrayerDay.empty(dateId));
    return _days(uid).doc(dateId).snapshots().map(
          (DocumentSnapshot<Map<String, Object?>> doc) =>
              doc.exists ? PrayerDay.fromDoc(doc) : PrayerDay.empty(dateId),
        );
  }

  /// The last [days] days, newest first — powers the streak calendar.
  Stream<StreakHistory> watchHistory({int days = 35}) {
    final String? uid = _auth.uid;
    if (uid == null) {
      return Stream<StreakHistory>.value(
        const StreakHistory(days: <String, PrayerDay>{}),
      );
    }
    final String from = Fmt.dayId(
      DateTime.now().subtract(Duration(days: days - 1)),
    );
    return _days(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(days)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, Object?>> snap) => StreakHistory(
            days: <String, PrayerDay>{
              for (final QueryDocumentSnapshot<Map<String, Object?>> doc
                  in snap.docs)
                doc.id: PrayerDay.fromDoc(doc),
            },
          ),
        );
  }

  // ── Two-step confirmation ─────────────────────────────────────────────

  /// **Step 1.** Records intent only. The prayer is explicitly *not* counted
  /// yet — it moves to `awaiting_proof` and the focus session stays open.
  Future<void> beginConfirmation({
    required PrayerId prayer,
    required DateTime scheduledAt,
    DateTime? now,
  }) async {
    final String uid = _requireUid();
    final DateTime moment = now ?? DateTime.now();
    final String dateId = Fmt.dayId(moment);

    await _days(uid).doc(dateId).set(<String, Object?>{
      'date': dateId,
      'updatedAt': FieldValue.serverTimestamp(),
      'prayers': <String, Object?>{
        prayer.key: <String, Object?>{
          'status': PrayerStatus.awaitingProof.key,
          'scheduledAt': Timestamp.fromDate(scheduledAt),
          'startedAt': Timestamp.fromDate(moment),
        },
      },
    }, SetOptions(merge: true),);
  }

  /// **Step 2.** Only this marks the prayer complete, and only after the photo
  /// is already in Storage — [proofPath] must be a real object path.
  ///
  /// Runs in a transaction with the streak update so a completed prayer and
  /// the counter can never disagree.
  Future<void> completeWithProof({
    required PrayerId prayer,
    required String proofPath,
    DateTime? now,
  }) async {
    if (proofPath.trim().isEmpty) {
      throw const AppFailure(
        'A prayer-mat photo is required to confirm this prayer.',
        code: 'proof-required',
      );
    }
    final String uid = _requireUid();
    final DateTime moment = now ?? DateTime.now();
    final String dateId = Fmt.dayId(moment);
    final DocumentReference<Map<String, Object?>> dayRef =
        _days(uid).doc(dateId);
    final DocumentReference<Map<String, Object?>> userRef = _auth.userDoc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, Object?>> daySnap =
          await tx.get(dayRef);
      final DocumentSnapshot<Map<String, Object?>> userSnap =
          await tx.get(userRef);

      final PrayerDay day = daySnap.exists
          ? PrayerDay.fromDoc(daySnap)
          : PrayerDay.empty(dateId);

      // Guard against a double-tap turning one prayer into two.
      if (day.recordFor(prayer).isCompleted) return;

      final Map<PrayerId, PrayerRecord> updated =
          Map<PrayerId, PrayerRecord>.from(day.records)
            ..[prayer] = PrayerRecord(
              status: PrayerStatus.completed,
              scheduledAt: day.recordFor(prayer).scheduledAt,
              startedAt: day.recordFor(prayer).startedAt,
              confirmedAt: moment,
              proofPath: proofPath,
            );

      final int completedCount = PrayerId.obligatory
          .where((PrayerId id) => updated[id]?.isCompleted ?? false)
          .length;
      final bool dayComplete = completedCount == PrayerId.obligatory.length;

      tx.set(
        dayRef,
        <String, Object?>{
          'date': dateId,
          'completedCount': completedCount,
          'isComplete': dayComplete,
          'updatedAt': FieldValue.serverTimestamp(),
          'prayers': <String, Object?>{
            prayer.key: updated[prayer]!.toMap(),
          },
        },
        SetOptions(merge: true),
      );

      final Map<String, Object?> stats =
          (userSnap.data()?['stats'] as Map<String, Object?>?) ??
              <String, Object?>{};
      final Map<String, Object?> nextStats = <String, Object?>{
        'totalPrayers': ((stats['totalPrayers'] as num?)?.toInt() ?? 0) + 1,
      };

      // The streak only moves when the *day* is finished, never per prayer.
      if (dayComplete) {
        final String? last = stats['lastCompletedDate'] as String?;
        final String yesterday =
            Fmt.dayId(moment.subtract(const Duration(days: 1)));
        final int current = (stats['currentStreak'] as num?)?.toInt() ?? 0;
        final int longest = (stats['longestStreak'] as num?)?.toInt() ?? 0;

        final int nextCurrent = switch (last) {
          final String l when l == dateId => current, // already counted today
          final String l when l == yesterday => current + 1,
          _ => 1,
        };
        nextStats['currentStreak'] = nextCurrent;
        nextStats['longestStreak'] =
            nextCurrent > longest ? nextCurrent : longest;
        nextStats['lastCompletedDate'] = dateId;
      }

      tx.set(
        userRef,
        <String, Object?>{'stats': nextStats},
        SetOptions(merge: true),
      );
    });
  }

  /// Called when a window closes with no confirmation.
  Future<void> markMissed({
    required PrayerId prayer,
    required String dateId,
  }) async {
    final String uid = _requireUid();
    await _days(uid).doc(dateId).set(<String, Object?>{
      'date': dateId,
      'prayers': <String, Object?>{
        prayer.key: <String, Object?>{'status': PrayerStatus.missed.key},
      },
    }, SetOptions(merge: true),);
  }

  /// Tahajjud is voluntary, so it is recorded without the photo step and never
  /// affects the five-prayer streak.
  Future<void> markTahajjud({DateTime? now}) async {
    final String uid = _requireUid();
    final DateTime moment = now ?? DateTime.now();
    // A 3 a.m. Tahajjud belongs to the night that began the previous evening.
    final DateTime attributedTo = moment.hour < 12
        ? moment.subtract(const Duration(days: 1))
        : moment;

    final WriteBatch batch = _db.batch();
    batch.set(
      _days(uid).doc(Fmt.dayId(attributedTo)),
      <String, Object?>{
        'date': Fmt.dayId(attributedTo),
        'tahajjud': <String, Object?>{
          'prayed': true,
          'at': Timestamp.fromDate(moment),
        },
      },
      SetOptions(merge: true),
    );
    batch.set(
      _auth.userDoc(uid),
      <String, Object?>{
        'stats': <String, Object?>{'totalTahajjud': FieldValue.increment(1)},
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  String _requireUid() {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('You need to be signed in to do that.');
    }
    return uid;
  }
}
