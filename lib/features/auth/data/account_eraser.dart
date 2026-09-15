import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Removes everything an account left in Firestore, before the sign-in itself
/// is deleted.
///
/// This used to be a Cloud Function, `onUserDeleted`, and the rules deferred
/// to it with `allow delete: if false`. The function has never been deployed —
/// the project is on the free Spark plan — so "delete my account" removed the
/// ability to sign in and left every document exactly where it was: the
/// profile with its photo and name, the scoreboard friends read, the code
/// document with the name printed on it. Both app stores require that
/// deleting an account deletes its data, and the privacy page says it does.
///
/// So the phone does it, in the order below. Nothing here can be done
/// server-side, which means it has to survive being interrupted: every step
/// is independent, a failure in one is logged and the rest still run, and
/// running the whole thing twice is harmless. What matters most goes first,
/// so that a deletion cut short by a dead battery has already taken away the
/// documents that carry a name, a face and a scoreboard.
class AccountEraser {
  const AccountEraser(this._db);

  final FirebaseFirestore _db;

  /// Firestore refuses a batch over 500 writes.
  static const int _batchLimit = 400;

  /// Erases everything owned by [uid]. Returns the names of the steps that
  /// did not finish, so the caller can decide whether to go on.
  ///
  /// An empty list means the account left nothing behind.
  Future<List<String>> erase(String uid) async {
    final List<String> failed = <String>[];

    Future<void> step(String name, Future<void> Function() body) async {
      try {
        await body();
      } on Object catch (error) {
        debugPrint('Layla Pro: could not erase $name — $error');
        failed.add(name);
      }
    }

    // The documents that carry a name, a face or a number a friend can read.
    await step('profile', () => _deleteDoc(_db.doc('users/$uid')));
    await step('scoreboard', () => _deleteDoc(_db.doc('progress/$uid')));
    await step('friend code', () => _releaseCode(uid));

    // The rest of this account's own subtrees.
    await step(
      'prayer history',
      () => _deleteQuery(_db.collection('users/$uid/prayer_days')),
    );
    await step(
      'tasbih sessions',
      () => _deleteQuery(_db.collection('users/$uid/tasbih_sessions')),
    );
    await step(
      'friends list',
      () => _deleteQuery(_db.collection('friends/$uid/list')),
    );
    await step(
      'blocks',
      () => _deleteQuery(_db.collection('friends/$uid/blocked')),
    );
    await step(
      'friend notes',
      () => _deleteQuery(_db.collection('friends/$uid/meta')),
    );
    await step(
      'cheers',
      () => _deleteQuery(_db.collection('cheers/$uid/from')),
    );
    await step('inbox', () => _deleteQuery(_db.collection('inbox/$uid/items')));
    await step('jumuah', () => _deleteDoc(_db.doc('jumuah/$uid')));
    await step(
      'tahajjud presence',
      () => _deleteDoc(_db.doc('tahajjud_presence/$uid')),
    );

    // Things that live on somebody else's screen: the mirror entry on each
    // friend's list, and this account's number inside each circle. Left
    // alone, a friend keeps a row for a person who no longer exists and a
    // circle keeps counting a member who cannot pray.
    await step('friends\' copies', () => _removeFromFriendLists(uid));
    await step('circles', () => _leaveCircles(uid));

    // Stories are public and signed with a name, so they go too.
    await step('stories', () => _deleteOwnStories(uid));

    return failed;
  }

  Future<void> _deleteDoc(DocumentReference<Map<String, Object?>> ref) =>
      ref.delete();

  /// Deletes every document a query returns, in batches.
  ///
  /// Reading first and deleting after is deliberate: a `limit` loop that
  /// re-queries after each batch can spin forever if a delete is refused,
  /// which is exactly what happens when a rule says no.
  Future<void> _deleteQuery(Query<Map<String, Object?>> query) async {
    final QuerySnapshot<Map<String, Object?>> snap = await query.get();
    await _deleteAll(
      snap.docs.map(
        (QueryDocumentSnapshot<Map<String, Object?>> d) => d.reference,
      ),
    );
  }

  Future<void> _deleteAll(
    Iterable<DocumentReference<Map<String, Object?>>> refs,
  ) async {
    final List<DocumentReference<Map<String, Object?>>> all = refs.toList();
    for (int i = 0; i < all.length; i += _batchLimit) {
      final WriteBatch batch = _db.batch();
      for (final DocumentReference<Map<String, Object?>> ref
          in all.skip(i).take(_batchLimit)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Gives the six-character code back, along with the marker that claims it.
  ///
  /// Both in one batch, because the rules only allow the marker to go when
  /// the code goes with it — a marker pointing at a code somebody else could
  /// then claim would be worse than either staying.
  Future<void> _releaseCode(String uid) async {
    final DocumentSnapshot<Map<String, Object?>> owner = await _db
        .doc('friend_code_owners/$uid')
        .get();
    final Object? code = owner.data()?['code'];
    if (code is! String || code.isEmpty) {
      // No code was ever claimed, or the marker is already gone.
      if (owner.exists) await owner.reference.delete();
      return;
    }
    final WriteBatch batch = _db.batch();
    batch.delete(_db.doc('friend_codes/$code'));
    batch.delete(owner.reference);
    await batch.commit();
  }

  /// Takes this account off the list of everyone it was friends with.
  ///
  /// The friendship is a pair of documents, and the rules let either side
  /// delete both — which is what removing a friend already does.
  Future<void> _removeFromFriendLists(String uid) async {
    final QuerySnapshot<Map<String, Object?>> mine = await _db
        .collection('friends/$uid/list')
        .get();
    await _deleteAll(
      mine.docs.map(
        (QueryDocumentSnapshot<Map<String, Object?>> d) =>
            _db.doc('friends/${d.id}/list/$uid'),
      ),
    );
  }

  /// Leaves every circle, and takes this account's number with it.
  ///
  /// Membership is an array on the circle document, so leaving is an update
  /// rather than a delete; the circle itself belongs to the people still in
  /// it and is never removed.
  Future<void> _leaveCircles(String uid) async {
    final QuerySnapshot<Map<String, Object?>> circles = await _db
        .collection('circles')
        .where('members', arrayContains: uid)
        .get();
    for (final QueryDocumentSnapshot<Map<String, Object?>> circle
        in circles.docs) {
      await _db
          .doc('circles/${circle.id}/progress/$uid')
          .delete()
          .catchError((Object _) {});
      await circle.reference.update(<String, Object?>{
        'members': FieldValue.arrayRemove(<String>[uid]),
      });
    }
  }

  Future<void> _deleteOwnStories(String uid) async {
    final QuerySnapshot<Map<String, Object?>> stories = await _db
        .collection('stories')
        .where('uid', isEqualTo: uid)
        .get();
    await _deleteAll(
      stories.docs.map(
        (QueryDocumentSnapshot<Map<String, Object?>> d) => d.reference,
      ),
    );
  }
}
