import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/story.dart';

final Provider<StoryRepository> storyRepositoryProvider =
    Provider<StoryRepository>(
      (Ref ref) => StoryRepository(
        ref.watch(firestoreProvider),
        ref.watch(authRepositoryProvider),
      ),
    );

class StoryRepository {
  const StoryRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final AuthRepository _auth;

  static const int _minLength = 40;
  static const int _maxLength = 1200;

  CollectionReference<Map<String, Object?>> get _stories =>
      _db.collection('stories');

  /// The public feed. `under_review` and `removed` stories never appear —
  /// enforced here *and* in `firestore.rules`.
  Stream<List<Story>> watchFeed({int limit = 50}) => _stories
      .where('status', isEqualTo: StoryStatus.published.key)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, Object?>> snap) =>
            snap.docs.map(Story.fromDoc).toList(growable: false),
      );

  Stream<List<Story>> watchMine({int limit = 30}) {
    final String? uid = _auth.uid;
    if (uid == null) return Stream<List<Story>>.value(const <Story>[]);
    return _stories
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, Object?>> snap) =>
              snap.docs.map(Story.fromDoc).toList(growable: false),
        );
  }

  Stream<Story?> watchStory(String id) => _stories
      .doc(id)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, Object?>> doc) =>
            doc.exists ? Story.fromDoc(doc) : null,
      );

  Future<bool> hasLiked(String storyId) async {
    final String? uid = _auth.uid;
    if (uid == null) return false;
    final DocumentSnapshot<Map<String, Object?>> doc = await _stories
        .doc(storyId)
        .collection('likes')
        .doc(uid)
        .get();
    return doc.exists;
  }

  Future<String> publish({
    required String body,
    required StoryMood mood,
    required bool anonymous,
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('Sign in to share a story.');
    }
    if (_auth.isGuest) {
      throw const AppFailure(
        'Sharing a story needs a full account. You can add an email and '
        'password from your profile and keep your streak.',
        code: 'guest-restricted',
      );
    }

    final String text = body.trim();
    if (text.length < _minLength) {
      throw const AppFailure('Please write at least 40 characters.');
    }
    if (text.length > _maxLength) {
      throw const AppFailure('Please keep your story under 1200 characters.');
    }

    final DocumentReference<Map<String, Object?>> doc = await _stories.add(
      <String, Object?>{
        'uid': uid,
        // The name is left out entirely when the author asked to be
        // anonymous — not written and then hidden by the UI.
        //
        // Hiding it client-side is not anonymity: every signed-in user can
        // read the document, so anyone querying Firestore directly would still
        // see the real name behind an "anonymous" story. People tick that box
        // before writing about grief, illness and 3am doubts, and that
        // decision has to be honoured in the data, not just the layout.
        if (!anonymous)
          'authorName': _auth.currentUser?.displayName ?? 'A believer',
        'isAnonymous': anonymous,
        'body': text,
        'mood': mood.key,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'reportCount': 0,
        'status': StoryStatus.published.key,
      },
    );
    return doc.id;
  }

  /// Likes live in a subcollection keyed by uid, so one person can only ever
  /// count once and the counter cannot be inflated from the client.
  Future<void> toggleLike(String storyId) async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    final DocumentReference<Map<String, Object?>> storyRef = _stories.doc(
      storyId,
    );
    final DocumentReference<Map<String, Object?>> likeRef = storyRef
        .collection('likes')
        .doc(uid);

    await _db.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, Object?>> like = await tx.get(likeRef);
      if (like.exists) {
        tx.delete(likeRef);
        tx.update(storyRef, <String, Object?>{
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        tx.set(likeRef, <String, Object?>{
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(storyRef, <String, Object?>{
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  /// Files a report. The `onStoryReported` Cloud Function counts them and
  /// moves a story to `under_review` at the threshold — clients never write
  /// `status` themselves.
  Future<void> report({
    required String storyId,
    required ReportReason reason,
    String note = '',
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('Sign in to report a story.');
    }
    await _db.collection('reports').add(<String, Object?>{
      'storyId': storyId,
      'reporterUid': uid,
      'reason': reason.key,
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  /// Authors can always remove their own story.
  Future<void> deleteMine(String storyId) async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    final DocumentSnapshot<Map<String, Object?>> doc = await _stories
        .doc(storyId)
        .get();
    if (doc.data()?['uid'] != uid) {
      throw const AppFailure('You can only delete your own story.');
    }
    await _stories.doc(storyId).delete();
  }
}
