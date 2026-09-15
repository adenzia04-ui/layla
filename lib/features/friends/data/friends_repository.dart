import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/friend.dart';
import '../domain/inbox_item.dart';
import '../domain/jumuah.dart';
import '../domain/ramadan.dart';

final Provider<FriendsRepository> friendsRepositoryProvider =
    Provider<FriendsRepository>(
      (Ref ref) => FriendsRepository(
        ref.watch(firestoreProvider),
        ref.watch(authRepositoryProvider),
      ),
    );

/// The collections behind Friends.
///
/// `friend_codes/{code}` maps a code to a uid and is the one thing a stranger
/// can look up; `friend_code_owners/{uid}` is the write-once record that this
/// account has claimed its one code. `friends/{uid}/list/{friendUid}` is the
/// friendship, written to both sides at once so neither list can disagree with
/// the other, and `friends/{uid}/blocked/{otherUid}` is what keeps a removed
/// friend removed. `progress/{uid}` is the scoreboard a person's friends are
/// allowed to read. The user document itself stays private throughout.
///
/// Round two added the things friends do for each other, each on its own
/// document so the rules can hold each to its shape: `cheers/{toUid}/from/
/// {fromUid}` is a MashaAllah on a milestone, `inbox/{toUid}/items/{id}` is a
/// verse, an Eid greeting or a circle invitation, `jumuah/{uid}` is which
/// masjid this Friday, and `friends/{uid}/meta/{friendUid}` is where a
/// friendship started counting prayers together. None of them carries free
/// text but the masjid name, and none of them ever carries anything about
/// the prayer pause.
class FriendsRepository {
  FriendsRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final AuthRepository _auth;

  /// How many fresh codes to try before giving up. A clash is a one in a
  /// billion event, so five is generous — the loop exists so that a clash is
  /// survivable, not because it is expected.
  static const int _codeAttempts = 5;

  /// How long a write is waited on before it is left to sync on its own.
  ///
  /// A Firestore write completes on server acknowledgement, so with no
  /// connection it stays pending while the change is already applied locally
  /// and queued. Nothing here should leave a switch or a button spinning for
  /// that: the value on screen has already moved, and the write goes out when
  /// the connection comes back.
  static const Duration _ack = Duration(seconds: 8);

  /// The most writes one batch may carry, a little under Firestore's 500.
  static const int _batchLimit = 400;

  /// The claim in flight, if there is one.
  ///
  /// The code card and "add a friend" both need a code and can ask for one in
  /// the same breath — the card's claim is still going out when the person
  /// taps Add. A code is claimed once per account and the rules pin that to a
  /// marker document that can never be unwritten, so the second claim is
  /// refused outright and the person is shown a bare permission error.
  /// Concurrent callers wait on the first claim instead of starting a second.
  Future<String>? _claiming;

  /// Friends whose start-of-count document is being written, or was refused.
  ///
  /// The write is triggered from a provider that rebuilds on every snapshot,
  /// so without this a slow acknowledgement would send the same document
  /// twice, and a refusal — the rules declining it — would be retried on
  /// every rebuild for as long as the card was on screen.
  final Set<String> _metaWrites = <String>{};

  CollectionReference<Map<String, Object?>> get _codes =>
      _db.collection('friend_codes');

  CollectionReference<Map<String, Object?>> get _codeOwners =>
      _db.collection('friend_code_owners');

  CollectionReference<Map<String, Object?>> get _progress =>
      _db.collection('progress');

  CollectionReference<Map<String, Object?>> get _jumuah =>
      _db.collection('jumuah');

  CollectionReference<Map<String, Object?>> _list(String uid) =>
      _db.collection('friends').doc(uid).collection('list');

  CollectionReference<Map<String, Object?>> _blocked(String uid) =>
      _db.collection('friends').doc(uid).collection('blocked');

  CollectionReference<Map<String, Object?>> _meta(String uid) =>
      _db.collection('friends').doc(uid).collection('meta');

  CollectionReference<Map<String, Object?>> _cheers(String toUid) =>
      _db.collection('cheers').doc(toUid).collection('from');

  CollectionReference<Map<String, Object?>> _inbox(String uid) =>
      _db.collection('inbox').doc(uid).collection('items');

  /// The code stored on a user document, in the form this app would accept.
  ///
  /// Normalised rather than taken as it is: a code written by an older build
  /// could be lowercased or carry its hyphen, and calling that "no code" would
  /// send the caller off to claim a second one — which the rules refuse for
  /// good, leaving a person with a friend code card that only ever errors.
  /// Read as an `Object?` because a non-string there would throw on the cast.
  String? _storedCode(DocumentSnapshot<Map<String, Object?>> user) {
    final Object? raw = user.data()?['friendCode'];
    if (raw is! String) return null;
    final String code = FriendCode.normalize(raw);
    return FriendCode.isValid(code) ? code : null;
  }

  /// The user's code, creating one the first time.
  ///
  /// The code document is claimed inside a transaction that reads it first
  /// and refuses if it already exists, so two people can never end up holding
  /// the same code — the rules make the document create-only as well. Once
  /// claimed it is written onto the user document, which is where every later
  /// call finds it.
  Future<String> ensureCode({required String uid, required String name}) async {
    final DocumentSnapshot<Map<String, Object?>> user = await _auth
        .userDoc(uid)
        .get();
    final String? existing = _storedCode(user);
    if (existing != null) return existing;
    return _claimOnce(uid: uid, name: name);
  }

  /// One claim at a time per repository — see [_claiming].
  Future<String> _claimOnce({required String uid, required String name}) =>
      _claiming ??= _recoverOrClaim(
        uid: uid,
        name: name,
      ).whenComplete(() => _claiming = null);

  /// The account's one code: the claimed one if a claim already landed, a
  /// fresh one otherwise.
  ///
  /// The marker document records the claim and is written in the same
  /// transaction as the code itself, so a connection lost between that
  /// transaction and the write onto the profile does not lose the code — and
  /// it must not be re-claimed, because the rules allow exactly one marker per
  /// account and refuse a second claim for good. It is read back here and
  /// filed on the profile, which is where every later call looks first.
  Future<String> _recoverOrClaim({
    required String uid,
    required String name,
  }) async {
    final DocumentSnapshot<Map<String, Object?>> marker = await _codeOwners
        .doc(uid)
        .get();
    final Object? raw = marker.data()?['code'];
    final String claimed = raw is String ? FriendCode.normalize(raw) : '';
    if (FriendCode.isValid(claimed)) {
      await _fileCode(uid: uid, code: claimed);
      return claimed;
    }
    return _claimCode(uid: uid, name: name);
  }

  /// Puts the code on the user document, where [ensureCode] finds it without
  /// reading the marker again.
  Future<void> _fileCode({required String uid, required String code}) => _auth
      .userDoc(uid)
      .set(<String, Object?>{'friendCode': code}, SetOptions(merge: true));

  Future<String> _claimCode({required String uid, required String name}) async {
    for (int attempt = 0; attempt < _codeAttempts; attempt++) {
      final String code = FriendCode.generate();
      final DocumentReference<Map<String, Object?>> ref = _codes.doc(code);
      final bool claimed = await _db.runTransaction<bool>((
        Transaction tx,
      ) async {
        final DocumentSnapshot<Map<String, Object?>> taken = await tx.get(ref);
        if (taken.exists) return false;
        tx.set(ref, <String, Object?>{
          'uid': uid,
          'name': FriendName.clean(name),
          'createdAt': FieldValue.serverTimestamp(),
        });
        // The marker goes in the same transaction because that is what the
        // rules check the claim against: `getAfter` on it has to see this very
        // code. It is create-only, so nobody can unwrite it and claim again.
        tx.set(_codeOwners.doc(uid), <String, Object?>{'code': code});
        return true;
      });
      if (!claimed) continue;

      await _fileCode(uid: uid, code: code);
      return code;
    }
    throw const AppFailure(
      'Layla Pro could not find a free friend code. Please try again.',
      code: 'friend-code-exhausted',
    );
  }

  /// Everyone on [uid]'s list, newest friendship first.
  Stream<List<Friend>> watchFriends(String uid) => _list(uid)
      .orderBy('since', descending: true)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, Object?>> snap) =>
            snap.docs.map(Friend.fromDoc).toList(growable: false),
      );

  /// One person's scoreboard. Null until they have published one — a friend
  /// added moments ago may not have opened the app since.
  Stream<FriendProgress?> watchProgress(String uid) => _progress
      .doc(uid)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, Object?>> doc) =>
            doc.exists ? FriendProgress.fromDoc(doc) : null,
      );

  /// Makes a friendship from a code someone typed.
  ///
  /// Both list documents go in one batch: either the two of you are friends
  /// or neither of you is, never one side only. The rules let either party
  /// write the other's side, which is what makes the batch possible from one
  /// phone. Throws [FriendAddException] for every reason the person can act
  /// on, including a batch the rules refuse — see [_commitAdd]. Anything else,
  /// no network above all, comes through as is.
  Future<Friend> addByCode(String rawCode) async {
    final String? me = _auth.uid;
    if (me == null) {
      throw const FriendAddException(FriendAddError.notSignedIn);
    }
    if (_auth.isGuest) {
      throw const FriendAddException(FriendAddError.guest);
    }

    final String code = FriendCode.normalize(rawCode);
    if (!FriendCode.isValid(code)) {
      throw const FriendAddException(FriendAddError.invalidCode);
    }

    final DocumentSnapshot<Map<String, Object?>> entry = await _codes
        .doc(code)
        .get();
    final String friendUid = entry.data()?['uid'] as String? ?? '';
    if (!entry.exists || friendUid.isEmpty) {
      throw const FriendAddException(FriendAddError.notFound);
    }
    if (friendUid == me) {
      throw const FriendAddException(FriendAddError.yourself);
    }

    final DocumentSnapshot<Map<String, Object?>> existing = await _list(
      me,
    ).doc(friendUid).get();
    if (existing.exists) {
      throw const FriendAddException(FriendAddError.already);
    }

    // The friend's side of the list needs my name and code. The name comes
    // from my own user document, which only I can read — so it is read here
    // and copied across, the same way names reach stories and the map.
    final DocumentSnapshot<Map<String, Object?>> mine = await _auth
        .userDoc(me)
        .get();
    final String myName = FriendName.clean(
      mine.data()?['displayName'] as String?,
    );
    final String myCode =
        _storedCode(mine) ?? await _claimOnce(uid: me, name: myName);

    // Both entries are built with no `since`, so each one carries
    // `FieldValue.serverTimestamp()` — the rules require exactly that, and a
    // client clock would be refused. The friend's name comes off their code
    // document, cleaned again here: a name written by an older build could be
    // blank or overlong, and the rules would turn that into a refusal the
    // person adding them could do nothing about.
    final Friend friend = Friend(
      uid: friendUid,
      name: FriendName.clean(entry.data()?['name'] as String?),
      code: code,
    );
    final Friend self = Friend(uid: me, name: myName, code: myCode);

    final WriteBatch batch = _db.batch();
    // Adding someone back lifts my own block on them, in the same batch the
    // rules check it against. Theirs, if they have one, is theirs to lift.
    batch.delete(_blocked(me).doc(friendUid));
    batch.set(_list(me).doc(friendUid), friend.toMap());
    batch.set(_list(friendUid).doc(me), self.toMap());
    await _commitAdd(batch, me: me, friendUid: friendUid);
    return friend;
  }

  /// Commits the two list documents, turning what the rules can refuse into
  /// something the person can read.
  ///
  /// A `set` over a document that already exists is an UPDATE to the rules,
  /// and a list entry is never updatable. So two friends sitting together and
  /// typing each other's codes at the same moment both get past the "already
  /// friends" check, one batch lands both documents, and the other — already
  /// in flight — is refused wholesale. The friendship is complete either way,
  /// which is what the loser of that race is told, rather than being shown a
  /// raw Firestore error. The same holds for a retry after a commit whose
  /// acknowledgement was lost. Anything else refused — most likely a block on
  /// the other side — becomes [FriendAddError.refused].
  Future<void> _commitAdd(
    WriteBatch batch, {
    required String me,
    required String friendUid,
  }) async {
    try {
      await batch.commit();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') rethrow;
      debugPrint('Layla Pro: friend add refused ($error)');
      final bool friends = await _listEntryExists(me: me, friendUid: friendUid);
      throw FriendAddException(
        friends ? FriendAddError.already : FriendAddError.refused,
      );
    }
  }

  /// Whether the friendship landed after all. Read from the server, so the
  /// answer is the other phone's write rather than this one's cache.
  Future<bool> _listEntryExists({
    required String me,
    required String friendUid,
  }) async {
    try {
      final DocumentSnapshot<Map<String, Object?>> now = await _list(
        me,
      ).doc(friendUid).get(const GetOptions(source: Source.server));
      return now.exists;
    } on Object catch (error) {
      // No connection, or the read refused too. Nothing says the friendship
      // exists, so the person is told the add did not go through.
      debugPrint('Layla Pro: friendship state unknown ($error)');
      return false;
    }
  }

  /// Ends a friendship from either side. Both list documents go in one
  /// batch, for the same reason [addByCode] writes both.
  ///
  /// Not waited on indefinitely: the commit's Future completes on server
  /// acknowledgement, and with no connection it stays pending while the
  /// deletes are already applied locally and queued. The list on screen has
  /// updated by then, so the caller should not be left spinning.
  Future<void> remove(String friendUid) async {
    final String? me = _auth.uid;
    if (me == null) return;
    final WriteBatch batch = _db.batch();
    batch.delete(_list(me).doc(friendUid));
    batch.delete(_list(friendUid).doc(me));
    // Removing someone has to mean something they cannot undo. They have read
    // their own list, so they have seen my code, and deleting the two entries
    // on its own would leave them free to write themselves back onto my list
    // — and back onto my scoreboard — whenever they liked. The block is what
    // the rules check before anyone lands on this list again; only I can lift
    // it, by adding them back.
    batch.set(_blocked(me).doc(friendUid), <String, Object?>{
      'since': FieldValue.serverTimestamp(),
    });
    await batch.commit().timeout(
      const Duration(seconds: 8),
      onTimeout: () => debugPrint(
        'Layla Pro: friend removed locally, will sync when back online',
      ),
    );
  }

  /// Writes what [p.uid]'s friends may see, stamped with the server clock so
  /// "updated 2h ago" means the same thing on every phone.
  ///
  /// The document is replaced wholesale, never merged. The map is complete —
  /// every field the rules allow is in it — and under a merge the rules see
  /// the POST-merge document, so a single field left behind by an older build
  /// would fail their `hasOnly` check and refuse every publish from then on,
  /// permanently and silently. Replacing sweeps such a field away instead.
  ///
  /// Replacing is also what takes a milestone or the Ramadan line off the
  /// scoreboard, and what makes going quiet hold on the server: the zeros in
  /// [p] land over the numbers, and the two optional maps are simply not in
  /// the document any more.
  Future<void> publishProgress(FriendProgress p) => _progress.doc(p.uid).set(
    <String, Object?>{...p.toMap(), 'updatedAt': FieldValue.serverTimestamp()},
  );

  // ── Going quiet ───────────────────────────────────────────────────────

  /// Turns the switch on the profile. The publisher watches it and sends
  /// zeros — see `myProgressProvider`; this only records the wish.
  Future<void> setQuiet(bool quiet) {
    final String me = _requireSignedIn();
    return _settle(
      _auth.userDoc(me).set(<String, Object?>{
        'quiet': quiet,
      }, SetOptions(merge: true)),
      'quiet',
    );
  }

  // ── Milestones ────────────────────────────────────────────────────────

  /// Records [key] as the latest milestone, stamped by the server, and every
  /// key in [crossed] as reached.
  ///
  /// The reached list is what makes the sync idempotent across launches and
  /// across counters: `Milestone.next` will not offer any key on it again.
  /// `arrayUnion` so that a key already there is not duplicated, and so that
  /// two devices recording at once merge rather than overwrite.
  Future<void> recordMilestone({
    required MilestoneKey key,
    required Set<MilestoneKey> crossed,
  }) {
    final String me = _requireSignedIn();
    return _settle(
      _auth.userDoc(me).set(<String, Object?>{
        'milestone': <String, Object?>{
          'key': key.key,
          'at': FieldValue.serverTimestamp(),
        },
        'milestonesReached': FieldValue.arrayUnion(<Object?>[
          for (final MilestoneKey reached in crossed) reached.key,
        ]),
      }, SetOptions(merge: true)),
      'milestone',
    );
  }

  /// A MashaAllah on [friendUid]'s milestone [key].
  ///
  /// The document id is this account, so saying it twice writes the same
  /// document twice and the friend counts one cheer. The rules take a create
  /// or an update here, stamped with the server clock either way.
  Future<void> cheer({required String friendUid, required MilestoneKey key}) {
    final String me = _requireSignedIn();
    return _settle(
      _cheers(friendUid).doc(me).set(<String, Object?>{
        'milestone': key.key,
        'at': FieldValue.serverTimestamp(),
      }),
      'cheer',
    );
  }

  /// How many friends have said MashaAllah to [uid]'s milestone [key], live.
  /// Only the owner may read their cheers, so [uid] is always the caller.
  Stream<int> watchCheers({required String uid, required MilestoneKey key}) =>
      _cheers(uid)
          .where('milestone', isEqualTo: key.key)
          .snapshots()
          .map((QuerySnapshot<Map<String, Object?>> snap) => snap.docs.length);

  // ── The inbox ─────────────────────────────────────────────────────────

  /// Everything friends have sent [uid] that has not been dismissed, newest
  /// first. A document that is not an item this app could have sent is left
  /// out rather than shown wrong — see `InboxItem.fromDoc`.
  Stream<List<InboxItem>> watchInbox(String uid) => _inbox(uid)
      .orderBy('at', descending: true)
      .snapshots()
      .map((QuerySnapshot<Map<String, Object?>> snap) {
        final List<InboxItem> items = <InboxItem>[];
        for (final QueryDocumentSnapshot<Map<String, Object?>> doc
            in snap.docs) {
          final InboxItem? item = InboxItem.fromDoc(doc);
          if (item != null) items.add(item);
        }
        return items;
      });

  /// Sends one of the app's own passages to a friend, by its `Comfort.id`.
  Future<void> sendVerse({
    required String friendUid,
    required String fromName,
    required String comfortId,
  }) {
    final String me = _requireSignedIn();
    final String id = comfortId.trim();
    if (id.isEmpty || id.length > InboxItem.maxComfortIdLength) {
      throw const AppFailure(
        'That passage could not be sent.',
        code: 'bad-comfort-id',
      );
    }
    return _settle(
      _inbox(friendUid).add(
        InboxItem.payload(
          type: InboxType.verse,
          fromUid: me,
          fromName: fromName,
          comfortId: id,
        ),
      ),
      'verse',
    );
  }

  /// Invites a friend into a circle: the circle's id, and the code that
  /// joins it. The friend's phone cannot read the circle until they are in
  /// it, so the code is the whole of the invitation.
  Future<void> sendCircleInvite({
    required String friendUid,
    required String fromName,
    required String circleId,
    required String circleCode,
  }) {
    final String me = _requireSignedIn();
    final String code = FriendCode.normalize(circleCode);
    if (circleId.isEmpty ||
        circleId.length > InboxItem.maxCircleIdLength ||
        !FriendCode.isValid(code)) {
      throw const AppFailure(
        'That invitation could not be sent.',
        code: 'bad-circle-invite',
      );
    }
    return _settle(
      _inbox(friendUid).add(
        InboxItem.payload(
          type: InboxType.circle,
          fromUid: me,
          fromName: fromName,
          circleId: circleId,
          circleCode: code,
        ),
      ),
      'circle invitation',
    );
  }

  /// Eid Mubarak to everyone on the list, and a note on the profile that this
  /// Eid's greeting has gone out.
  ///
  /// The greetings and the note go in one batch, so a relaunch cannot find
  /// the note without the greetings having landed — or the greetings sent
  /// without the note, which would send them again. A list longer than a
  /// batch is sent in several, the note riding with the last.
  Future<void> sendEid({
    required List<String> friendUids,
    required String fromName,
    required String eidKey,
  }) async {
    final String me = _requireSignedIn();
    final Map<String, Object?> greeting = InboxItem.payload(
      type: InboxType.eid,
      fromUid: me,
      fromName: fromName,
    );
    final Map<String, Object?> note = <String, Object?>{
      'eidSent': <String, Object?>{eidKey: true},
    };
    // Always at least one batch, so the note is written even to an empty
    // list: with nobody to greet there is nothing to come back to.
    for (
      int start = 0;
      start == 0 || start < friendUids.length;
      start += _batchLimit
    ) {
      final int end = start + _batchLimit < friendUids.length
          ? start + _batchLimit
          : friendUids.length;
      final WriteBatch batch = _db.batch();
      for (final String uid in friendUids.sublist(start, end)) {
        batch.set(_inbox(uid).doc(), greeting);
      }
      if (end == friendUids.length) {
        batch.set(_auth.userDoc(me), note, SetOptions(merge: true));
      }
      await _settle(batch.commit(), 'Eid greetings');
    }
  }

  /// Takes an item off the owner's inbox for good.
  Future<void> dismissInbox(String itemId) {
    final String me = _requireSignedIn();
    return _settle(_inbox(me).doc(itemId).delete(), 'inbox');
  }

  // ── Jumu'ah ───────────────────────────────────────────────────────────

  /// Which masjid [uid] is going to, as stored — the caller decides whether
  /// the Friday on it is still the coming one.
  Stream<Jumuah?> watchJumuah(String uid) => _jumuah
      .doc(uid)
      .snapshots()
      .map(
        (DocumentSnapshot<Map<String, Object?>> doc) =>
            doc.exists ? Jumuah.fromDoc(doc) : null,
      );

  /// Names the masjid for the Friday [date]. The only typed words a friend
  /// ever reads, held to `Jumuah.maxLength` here and in the rules.
  Future<void> setJumuah({required String masjid, required String date}) {
    final String me = _requireSignedIn();
    final String name = Jumuah.clean(masjid);
    if (name.isEmpty) {
      throw const AppFailure('Give the masjid a name.', code: 'blank-masjid');
    }
    return _settle(
      _jumuah.doc(me).set(Jumuah(masjid: name, date: date).toMap()),
      "Jumu'ah",
    );
  }

  // ── Prayers together ──────────────────────────────────────────────────

  /// Where the count with [friendUid] started, or null before it has.
  Stream<FriendMeta?> watchMeta(String friendUid) {
    final String? me = _auth.uid;
    if (me == null) return Stream<FriendMeta?>.value(null);
    return _meta(me)
        .doc(friendUid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, Object?>> doc) =>
              doc.exists ? FriendMeta.fromDoc(doc) : null,
        );
  }

  /// Writes where the count with [friendUid] starts: both totals as they
  /// stand right now. Once per friend per launch, refused or not — see
  /// [_metaWrites]. Never throws; the provider that calls it has nothing to
  /// do with a failure, and the next launch tries again.
  Future<void> writeMeta({
    required String friendUid,
    required int myStartTotal,
    required int theirStartTotal,
  }) async {
    final String? me = _auth.uid;
    if (me == null || !_metaWrites.add(friendUid)) return;
    try {
      await _settle(
        _meta(me)
            .doc(friendUid)
            .set(
              FriendMeta(
                myStartTotal: myStartTotal,
                theirStartTotal: theirStartTotal,
              ).toMap(),
            ),
        'friendship start',
      );
    } on Object catch (error) {
      debugPrint('Layla Pro: friendship start not recorded ($error)');
    }
  }

  // ── Ramadan ───────────────────────────────────────────────────────────

  /// Saves the owner's own Ramadan record. The scoreboard never carries this
  /// map; the publisher derives what friends see from it.
  Future<void> setRamadan(RamadanRecord record) {
    final String me = _requireSignedIn();
    return _settle(
      _auth.userDoc(me).set(<String, Object?>{
        'ramadan': record.toMap(),
      }, SetOptions(merge: true)),
      'Ramadan',
    );
  }

  /// The signed-in account, or a failure the screen can show.
  ///
  /// Only the sign-in is checked here, not whether the account is a guest:
  /// the auth user goes on saying anonymous after a guest links an email,
  /// and every caller already hangs off `friendsUidProvider`, which reads the
  /// profile for that. The rules refuse a real guest regardless.
  String _requireSignedIn() {
    final String? me = _auth.uid;
    if (me == null) {
      throw const AppFailure('Sign in to do that.', code: 'not-signed-in');
    }
    return me;
  }

  /// Waits for [write] to be acknowledged, or for [_ack] to pass, whichever
  /// is first — see there. Named for the write and not for its contents, as
  /// the cycle catch-up's log line is, because `debugPrint` reaches the
  /// device log.
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
