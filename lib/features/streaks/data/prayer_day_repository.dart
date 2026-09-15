import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../cycle/domain/cycle.dart';
import '../../prayer_times/domain/prayer.dart';
import '../domain/prayer_day.dart';
import '../domain/streak_math.dart';

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
    return _days(uid)
        .doc(dateId)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, Object?>> doc) =>
              doc.exists ? PrayerDay.fromDoc(doc) : PrayerDay.empty(dateId),
        );
  }

  /// Every recorded day of [year], for the year view and the streak stats.
  ///
  /// Ascending by document id, which is the order Firestore keeps for free.
  /// This used to ask for the last five weeks *newest first*, and a
  /// descending sort on document ids is the one order Firestore will not
  /// serve without a composite index — so every open of the streak screen
  /// failed with `failed-precondition`. A whole year is at most 366 small
  /// documents, so it is fetched in one range and sorted nowhere.
  Stream<StreakHistory> watchYear(int year) {
    final String? uid = _auth.uid;
    if (uid == null) {
      return Stream<StreakHistory>.value(
        StreakHistory(year: year, days: const <String, PrayerDay>{}),
      );
    }
    return _days(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '$year-01-01')
        .where(FieldPath.documentId, isLessThanOrEqualTo: '$year-12-31')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, Object?>> snap) => StreakHistory(
            year: year,
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
    }, SetOptions(merge: true));
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
  }) {
    if (proofPath.trim().isEmpty) {
      throw const AppFailure(
        'A prayer-mat photo is required to confirm this prayer.',
        code: 'proof-required',
      );
    }
    return _complete(prayer: prayer, proofPath: proofPath, now: now);
  }

  /// The one-tap confirmation, for those without the mat scan: the prayer is
  /// completed on their word, and the streak moves exactly as it would with
  /// a photo. Premium adds the proof; it does not change the arithmetic.
  Future<void> completeWithoutProof({
    required PrayerId prayer,
    DateTime? now,
  }) => _complete(prayer: prayer, proofPath: null, now: now);

  Future<void> _complete({
    required PrayerId prayer,
    required String? proofPath,
    DateTime? now,
  }) async {
    final String uid = _requireUid();
    final DateTime moment = now ?? DateTime.now();
    final String dateId = Fmt.dayId(moment);
    final DocumentReference<Map<String, Object?>> dayRef = _days(
      uid,
    ).doc(dateId);
    final DocumentReference<Map<String, Object?>> userRef = _auth.userDoc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, Object?>> daySnap = await tx.get(
        dayRef,
      );
      final DocumentSnapshot<Map<String, Object?>> userSnap = await tx.get(
        userRef,
      );

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
      // An excused day is never "complete", so confirming a prayer on one
      // counts the prayer and leaves the chain alone. She may pray the moment
      // the pause ends, and that prayer should be recorded — but the day has
      // already carried `lastCompletedDate` forward once, and letting it do so
      // twice is how a pause would start inflating a streak.
      final bool dayComplete =
          !day.excused && completedCount == PrayerId.obligatory.length;

      tx.set(dayRef, <String, Object?>{
        'date': dateId,
        'completedCount': completedCount,
        'isComplete': dayComplete,
        'updatedAt': FieldValue.serverTimestamp(),
        'prayers': <String, Object?>{prayer.key: updated[prayer]!.toMap()},
      }, SetOptions(merge: true));

      final Map<String, Object?> stats =
          (userSnap.data()?['stats'] as Map<String, Object?>?) ??
          <String, Object?>{};
      final Map<String, Object?> nextStats = <String, Object?>{
        'totalPrayers': ((stats['totalPrayers'] as num?)?.toInt() ?? 0) + 1,
      };

      // The streak only moves when the *day* is finished, never per prayer.
      if (dayComplete) {
        nextStats.addAll(
          StreakStats.fromMap(stats).afterCompletedDay(dateId).toMap(),
        );
      }

      tx.set(userRef, <String, Object?>{
        'stats': nextStats,
      }, SetOptions(merge: true));
    });
  }

  // ── The prayer pause ──────────────────────────────────────────────────

  /// Records a day the prayer pause covers.
  ///
  /// The day is marked `excused`, its prayers carry `PrayerStatus.excused`,
  /// and the chain is carried forward onto it *without* `currentStreak` being
  /// touched — the invariant is written out in full on
  /// `StreakStats.afterExcusedDay`, and this is the only place that applies
  /// it. Nothing here is ever a debt: these prayers are not made up.
  ///
  /// Idempotent, because the catch-up calls it on every app open: a day that
  /// is already excused and has already carried the chain writes nothing at
  /// all, so opening the app ten times in one day costs one read and no
  /// writes, and the streak cannot drift.
  ///
  /// Prayers already confirmed on this day are left exactly as they are. A
  /// pause that begins in the evening must not erase the Fajr she prayed that
  /// morning — and a day where all five were already prayed is left alone
  /// entirely: it is finished, the chain was carried by the completion itself,
  /// and there is nothing left on it to excuse.
  Future<void> markExcused({required String dateId}) async {
    final String uid = _requireUid();
    final DocumentReference<Map<String, Object?>> dayRef = _days(
      uid,
    ).doc(dateId);
    final DocumentReference<Map<String, Object?>> userRef = _auth.userDoc(uid);

    await _db.runTransaction((Transaction tx) async {
      // Every read before every write — a transaction that interleaves them
      // is rejected by Firestore.
      final DocumentSnapshot<Map<String, Object?>> daySnap = await tx.get(
        dayRef,
      );
      final DocumentSnapshot<Map<String, Object?>> userSnap = await tx.get(
        userRef,
      );

      final PrayerDay day = daySnap.exists
          ? PrayerDay.fromDoc(daySnap)
          : PrayerDay.empty(dateId);

      // The whole decision, made outside Firestore so it can be tested there:
      // see `ExcusedDayWrite`.
      final StreakStats stats = StreakStats.fromMap(
        userSnap.data()?['stats'] as Map<String, Object?>?,
      );
      final ExcusedDayWrite write = ExcusedDayWrite.decide(
        dateId: dateId,
        dayIsComplete: day.isComplete,
        dayIsExcused: day.excused,
        stats: stats,
      );
      if (write.isEmpty) return;

      if (write.marksDay) {
        tx.set(dayRef, <String, Object?>{
          'date': dateId,
          'excused': true,
          'isComplete': false,
          'updatedAt': FieldValue.serverTimestamp(),
          'prayers': <String, Object?>{
            for (final PrayerId id in PrayerId.obligatory)
              if (!day.recordFor(id).isCompleted)
                id.key: <String, Object?>{'status': PrayerStatus.excused.key},
          },
        }, SetOptions(merge: true));
      }

      // The date, and `currentStreak` only when the arithmetic actually moved
      // it. `longestStreak` is never written back — it is a record of what was
      // achieved and nothing here can add to it — and the ordinary case stays
      // a two-field merge, so a confirmation landing on another device is not
      // clobbered by counters read a moment ago.
      //
      // `currentStreak` has to be writable at all because
      // `StreakStats.afterExcusedDay` can drop it to zero: a pause beginning
      // after a chain had already lapsed unremarked must not resurrect it.
      // Computing that reset and then declining to write it would leave the
      // resurrection in Firestore, which is where every other device reads it.
      //
      // `lastConfirmedDate` is written even though the pause never moves it,
      // and that is deliberate: the key's presence is what retires the
      // migration fallback in `StreakStats.fromMap`, so the scoreboard cannot
      // later mistake an excused date for a confirmed one.
      final StreakStats? next = write.stats;
      if (next != null) {
        tx.set(userRef, <String, Object?>{
          'stats': <String, Object?>{
            'lastCompletedDate': next.lastCompletedDate,
            'lastConfirmedDate': next.lastConfirmedDate,
            if (next.currentStreak != stats.currentStreak)
              'currentStreak': next.currentStreak,
          },
        }, SetOptions(merge: true));
      }
    });
  }

  /// Puts a missed prayer back to pending.
  ///
  /// "I missed this" is one tap next to the button people actually want, and
  /// until now it was final — a mis-tap cost a prayer for good, with the
  /// confirmation flow closed and no way back. Recording a miss should be
  /// honest, not punitive, and a mistake is not a miss.
  ///
  /// The streak is deliberately **not** restored here. Marking a miss zeroes
  /// `currentStreak`, and this cannot know whether the chain would have
  /// survived — that is the Cloud Function's job, from the day records. So
  /// reopening gives back the chance to confirm the prayer; it does not hand
  /// back a streak that was never earned.
  Future<void> reopen({
    required PrayerId prayer,
    required String dateId,
  }) async {
    final String uid = _requireUid();

    // Nothing to reopen on a day the pause covers: there is no missed prayer
    // there to put back. Setting one to `pending` would be worse than a no-op
    // — it would bring back the choices, the reminder and the lock for a
    // prayer she does not owe.
    //
    // The profile is asked first and the day second, because the two do not
    // agree straight away. `excused` is written by the catch-up, which is a
    // network round trip behind the profile and, offline, may not land that
    // session at all — so on every cold open from the second day of a pause
    // onwards the day document alone would say the day is ordinary. The pause
    // itself is the fact; the flag is only its record.
    if (await _pauseCovers(uid: uid, dateId: dateId)) return;

    final DocumentSnapshot<Map<String, Object?>> snap = await _days(
      uid,
    ).doc(dateId).get();
    if (snap.exists && PrayerDay.fromDoc(snap).excused) return;

    await _days(uid).doc(dateId).set(<String, Object?>{
      'date': dateId,
      'isComplete': false,
      'prayers': <String, Object?>{
        prayer.key: <String, Object?>{
          'status': PrayerStatus.pending.key,
          // Any half-finished confirmation goes with it, or the prayer comes
          // back already awaiting a photo nobody took.
          'confirmedAt': null,
          'proofPath': null,
          'startedAt': null,
        },
      },
    }, SetOptions(merge: true));
  }

  /// Called when a window closes with no confirmation, or when the user says
  /// outright that they missed it.
  ///
  /// This also ends the streak. A day needs all five, so the moment one is
  /// missed the day cannot complete — and the streak counter used only ever to
  /// go up, on a finished day. Miss Dhuhr and it sat at three until some later
  /// complete day quietly reset it to one, showing a streak that had already
  /// been broken for days.
  ///
  /// Nothing on a day the prayer pause covers can be marked missed. The UI
  /// never offers it there, and this refuses it anyway. A missed prayer is one
  /// that was owed and not prayed; on a paused day none of them were owed, and
  /// recording one would do the two things this whole feature exists to
  /// prevent — tell a woman she owes prayers she does not, and zero a streak
  /// the pause was carrying.
  Future<void> markMissed({
    required PrayerId prayer,
    required String dateId,
  }) async {
    final String uid = _requireUid();
    final DocumentReference<Map<String, Object?>> dayRef = _days(
      uid,
    ).doc(dateId);
    final DocumentReference<Map<String, Object?>> userRef = _auth.userDoc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, Object?>> daySnap = await tx.get(
        dayRef,
      );
      final DocumentSnapshot<Map<String, Object?>> userSnap = await tx.get(
        userRef,
      );

      // Both signals, and the profile's is the one that matters. `excused` is
      // written by the catch-up and lags the pause by a network round trip —
      // longer offline — so guarding on it alone leaves this open on exactly
      // the cold opens the pause is most likely to be running through. No
      // extra read: the user document is already fetched here for the stats.
      if (_pausedOn(userSnap.data(), dateId)) return;
      if (daySnap.exists && PrayerDay.fromDoc(daySnap).excused) return;

      tx.set(dayRef, <String, Object?>{
        'date': dateId,
        'isComplete': false,
        'prayers': <String, Object?>{
          prayer.key: <String, Object?>{'status': PrayerStatus.missed.key},
        },
      }, SetOptions(merge: true));

      final StreakStats stats = StreakStats.fromMap(
        userSnap.data()?['stats'] as Map<String, Object?>?,
      );
      final StreakStats next = stats.afterMissedDay();
      // longestStreak is a record of what was achieved and is left alone;
      // lastCompletedDate is cleared so tomorrow starts from one rather than
      // continuing from a day whose chain is now broken. That is also what
      // breaks a chain the pause had been carrying: the pause only ever moved
      // a date forward, and this drops it.
      if (next != stats) {
        tx.set(userRef, <String, Object?>{
          'stats': <String, Object?>{
            'currentStreak': next.currentStreak,
            'lastCompletedDate': next.lastCompletedDate,
            // Carried across unchanged — a miss today does not un-confirm a
            // day finished last week — and written so the key is pinned even
            // on an account old enough to still be relying on the migration
            // fallback in `StreakStats.fromMap`.
            'lastConfirmedDate': next.lastConfirmedDate,
          },
        }, SetOptions(merge: true));
      }
    });
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
    batch.set(_days(uid).doc(Fmt.dayId(attributedTo)), <String, Object?>{
      'date': Fmt.dayId(attributedTo),
      'tahajjud': <String, Object?>{
        'prayed': true,
        'at': Timestamp.fromDate(moment),
      },
    }, SetOptions(merge: true));
    batch.set(_auth.userDoc(uid), <String, Object?>{
      'stats': <String, Object?>{'totalTahajjud': FieldValue.increment(1)},
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Whether the prayer pause on [data] — a raw user document — covers
  /// [dateId].
  ///
  /// Every day from the start of a running pause onwards, with no reference to
  /// `CycleDays.covered`: that has a write cap on it, and a guard that stopped
  /// refusing on the ninety-first day of a forgotten pause would be worse than
  /// no guard at all.
  static bool _pausedOn(Map<String, Object?>? data, String dateId) {
    final Cycle cycle = Cycle.fromMap(
      data?['cycle'] is Map<String, Object?>
          ? data!['cycle'] as Map<String, Object?>
          : null,
    );
    return cycle.isActive && cycle.startedOn!.compareTo(dateId) <= 0;
  }

  Future<bool> _pauseCovers({
    required String uid,
    required String dateId,
  }) async {
    final DocumentSnapshot<Map<String, Object?>> snap = await _auth
        .userDoc(uid)
        .get();
    return _pausedOn(snap.data(), dateId);
  }

  String _requireUid() {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('You need to be signed in to do that.');
    }
    return uid;
  }
}
