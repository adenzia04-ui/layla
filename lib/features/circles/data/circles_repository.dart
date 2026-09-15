import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/domain/friend.dart';
import '../../streaks/domain/prayer_day.dart';
import '../domain/circle.dart';

final Provider<CirclesRepository> circlesRepositoryProvider =
    Provider<CirclesRepository>(
      (Ref ref) => CirclesRepository(
        ref.watch(firestoreProvider),
        ref.watch(authRepositoryProvider),
      ),
    );

/// The three collections behind circles.
///
/// `circles/{circleId}` is the circle, readable by its members; `circle_codes/
/// {code}` maps a code to a circle and is the one thing a non-member can
/// look up, which is how joining works without reading the circle first;
/// `circles/{circleId}/progress/{uid}` is one number per member, written by
/// that member's own phone. The days behind that number are read here from
/// the owner's own `users/{uid}/prayer_days`, which nobody else can read, and
/// nothing about any single day — least of all whether the prayer pause
/// covered it — is ever written back out.
class CirclesRepository {
  CirclesRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final AuthRepository _auth;

  /// How many fresh codes to try before giving up — see
  /// `FriendsRepository`, which has the same loop for the same reason.
  static const int _codeAttempts = 5;

  /// How long a write is waited on before it is left to sync on its own; see
  /// `FriendsRepository` for why a write is not waited on for ever.
  static const Duration _ack = Duration(seconds: 8);

  CollectionReference<Map<String, Object?>> get _circles =>
      _db.collection('circles');

  CollectionReference<Map<String, Object?>> get _codes =>
      _db.collection('circle_codes');

  CollectionReference<Map<String, Object?>> _progress(String circleId) =>
      _circles.doc(circleId).collection('progress');

  CollectionReference<Map<String, Object?>> _days(String uid) =>
      _db.collection('users').doc(uid).collection('prayer_days');

  /// Every circle [uid] is in, newest first. A document that is not a
  /// circle this app could have made is left out — see `Circle.fromDoc`.
  ///
  /// Sorted here rather than in the query: an `arrayContains` filter with an
  /// `orderBy` on another field is the kind of query Firestore refuses until
  /// a composite index exists, and a few circles sort for nothing.
  Stream<List<Circle>> watchMine(String uid) => _circles
      .where('members', arrayContains: uid)
      .snapshots()
      .map((QuerySnapshot<Map<String, Object?>> snap) {
        final List<Circle> circles = <Circle>[];
        for (final QueryDocumentSnapshot<Map<String, Object?>> doc
            in snap.docs) {
          final Circle? circle = Circle.fromDoc(doc);
          if (circle != null) circles.add(circle);
        }
        circles.sort(_newestFirst);
        return circles;
      });

  static int _newestFirst(Circle a, Circle b) {
    final DateTime? at = a.createdAt;
    final DateTime? bt = b.createdAt;
    // A circle still waiting for its server stamp is the newest of all.
    if (at == null) return bt == null ? 0 : -1;
    if (bt == null) return 1;
    return bt.compareTo(at);
  }

  /// One circle, live. Null once it cannot be read — after leaving it.
  Stream<Circle?> watchCircle(String circleId) => _circles
      .doc(circleId)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, Object?>> doc) =>
            doc.exists ? Circle.fromDoc(doc) : null,
      );

  /// One circle, once. Null when it does not exist or cannot be read.
  Future<Circle?> fetch(String circleId) async {
    final DocumentSnapshot<Map<String, Object?>> doc = await _circles
        .doc(circleId)
        .get();
    return doc.exists ? Circle.fromDoc(doc) : null;
  }

  /// Every member's count for one circle, live.
  Stream<List<CircleProgress>> watchProgress(String circleId) =>
      _progress(circleId).snapshots().map(
        (QuerySnapshot<Map<String, Object?>> snap) => <CircleProgress>[
          for (final QueryDocumentSnapshot<Map<String, Object?>> doc
              in snap.docs)
            CircleProgress.fromDoc(doc),
        ],
      );

  /// The owner's own recorded days from [from] to [to] inclusive, live.
  ///
  /// One range over the document ids, which are the dates, so Firestore
  /// serves a circle's forty days in order for free. This is the only read
  /// circles make of the private day documents, and what comes back is folded
  /// into a single count before anything is written anywhere.
  Stream<List<PrayerDay>> watchMyDays({
    required String uid,
    required String from,
    required String to,
  }) => _days(uid)
      .where(FieldPath.documentId, isGreaterThanOrEqualTo: from)
      .where(FieldPath.documentId, isLessThanOrEqualTo: to)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, Object?>> snap) => <PrayerDay>[
          for (final QueryDocumentSnapshot<Map<String, Object?>> doc
              in snap.docs)
            PrayerDay.fromDoc(doc),
        ],
      );

  /// Makes a circle, starting today, with the caller as its only member.
  ///
  /// The circle and its code document go in one batch, which is what the
  /// rules check them against: the code exists only alongside a circle
  /// whose `code` field names it. The code document is create-only, so a
  /// clash — one in a billion — refuses the whole batch, and the loop tries
  /// a fresh code. A refusal for any other reason is passed on as a failure
  /// the screen can show.
  Future<Circle> create({
    required String name,
    required CircleGoal goal,
    DateTime? now,
  }) async {
    final String me = _requireSignedIn();
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppFailure('Give the circle a name.', code: 'blank-name');
    }
    final String startsOn = Fmt.dayId(now ?? DateTime.now());

    for (int attempt = 0; attempt < _codeAttempts; attempt++) {
      final String code = FriendCode.generate();
      final DocumentReference<Map<String, Object?>> ref = _circles.doc();
      final Circle circle = Circle(
        id: ref.id,
        // Cut to forty the way every other name here is; the blank case was
        // refused above, so the fallback name can never be reached.
        name: FriendName.clean(trimmed),
        goal: goal,
        startsOn: startsOn,
        code: code,
        createdBy: me,
        members: <String>[me],
      );

      final WriteBatch batch = _db.batch();
      batch.set(ref, circle.toMap());
      batch.set(_codes.doc(code), <String, Object?>{'circleId': ref.id});
      try {
        await _settle(batch.commit(), 'circle');
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
        // Either the code was already taken — its document is create-only —
        // or the rules refused this account. The code document tells the two
        // apart, and only the first is worth another try.
        final DocumentSnapshot<Map<String, Object?>> taken = await _codes
            .doc(code)
            .get();
        if (taken.exists) continue;
        throw AppFailure.from(error);
      }
      return circle;
    }
    throw const AppFailure(
      'Layla Pro could not find a free circle code. Please try again.',
      code: 'circle-code-exhausted',
    );
  }

  /// Joins the circle behind [rawCode] and hands back its id.
  ///
  /// The code document is the only thing a non-member can read, so the join
  /// is a blind `arrayUnion` onto a circle this phone has never seen — the
  /// rules check that the update adds exactly this account and nothing else,
  /// and that the circle has room. Throws [CircleJoinException] for every
  /// reason the person can act on.
  Future<String> join(String rawCode) async {
    final String? me = _auth.uid;
    if (me == null) {
      throw const CircleJoinException(CircleJoinError.notSignedIn);
    }
    if (_auth.isGuest) {
      throw const CircleJoinException(CircleJoinError.guest);
    }

    final String code = FriendCode.normalize(rawCode);
    if (!FriendCode.isValid(code)) {
      throw const CircleJoinException(CircleJoinError.invalidCode);
    }

    final DocumentSnapshot<Map<String, Object?>> entry = await _codes
        .doc(code)
        .get();
    final Object? circleId = entry.data()?['circleId'];
    if (!entry.exists || circleId is! String || circleId.isEmpty) {
      throw const CircleJoinException(CircleJoinError.notFound);
    }

    try {
      await _settle(
        _circles.doc(circleId).update(<String, Object?>{
          'members': FieldValue.arrayUnion(<Object?>[me]),
        }),
        'circle join',
      );
    } on FirebaseException catch (error) {
      if (error.code == 'not-found') {
        throw const CircleJoinException(CircleJoinError.notFound);
      }
      if (error.code != 'permission-denied') rethrow;
      // Already in it — a join that adds nobody is refused too — or full, or
      // gone. A member can read the circle; a stranger cannot.
      throw CircleJoinException(
        await _isMember(circleId, me)
            ? CircleJoinError.already
            : CircleJoinError.refused,
      );
    }
    return circleId;
  }

  Future<bool> _isMember(String circleId, String uid) async {
    try {
      final Circle? circle = await fetch(circleId);
      return circle != null && circle.members.contains(uid);
    } on Object {
      return false;
    }
  }

  /// Leaves a circle. The count already published stays, as the record of
  /// the days that were kept while in it; the rules keep it readable to the
  /// members who remain.
  Future<void> leave(String circleId) {
    final String me = _requireSignedIn();
    return _settle(
      _circles.doc(circleId).update(<String, Object?>{
        'members': FieldValue.arrayRemove(<Object?>[me]),
      }),
      'circle leave',
    );
  }

  /// Publishes the caller's own count for one circle: one integer, stamped
  /// by the server.
  Future<void> publishKept({required String circleId, required int kept}) {
    final String me = _requireSignedIn();
    return _settle(
      _progress(circleId)
          .doc(me)
          .set(
            CircleProgress(uid: me, kept: kept.clamp(0, Circle.length)).toMap(),
          ),
      'circle progress',
    );
  }

  String _requireSignedIn() {
    final String? me = _auth.uid;
    if (me == null) {
      throw const AppFailure('Sign in to do that.', code: 'not-signed-in');
    }
    return me;
  }

  /// Waits for [write] to be acknowledged, or for [_ack] to pass.
  Future<void> _settle(Future<Object?> write, String what) async {
    await write.timeout(
      _ack,
      onTimeout: () {
        debugPrint('Layla Pro: $what saved locally, will sync when online');
        return null;
      },
    );
  }
}
