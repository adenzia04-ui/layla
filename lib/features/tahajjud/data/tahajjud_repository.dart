import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/geohash.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/tahajjud_presence.dart';

/// How long a Tahajjud presence lives before it disappears on its own, even if
/// the app is killed mid-session.
/// How long "I am praying" keeps you on the map.
///
/// Four hours: long enough to carry a light from the last third of the night
/// through to Fajr, short enough that nobody stays on the map into the
/// afternoon because they slept. Leaving early is still one tap.
const Duration kTahajjudSessionDuration = Duration(hours: 4);

final Provider<TahajjudRepository> tahajjudRepositoryProvider =
    Provider<TahajjudRepository>(
      (Ref ref) => TahajjudRepository(
        ref.watch(firestoreProvider),
        ref.watch(authRepositoryProvider),
      ),
    );

class TahajjudRepository {
  const TahajjudRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final AuthRepository _auth;

  CollectionReference<Map<String, Object?>> get _presence =>
      _db.collection('tahajjud_presence');

  /// Everyone currently praying. Filtered on `expiresAt` as well as `active`
  /// so a crashed client cannot leave a ghost on the map.
  Stream<List<TahajjudPresence>> watchActive({int limit = 300}) => _presence
      .where('active', isEqualTo: true)
      .where('expiresAt', isGreaterThan: Timestamp.now())
      .orderBy('expiresAt')
      .limit(limit)
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, Object?>> snap) =>
            snap.docs.map(TahajjudPresence.fromDoc).toList(growable: false),
      );

  Stream<TahajjudPresence?> watchMySession() {
    final String? uid = _auth.uid;
    if (uid == null) return Stream<TahajjudPresence?>.value(null);
    return _presence.doc(uid).snapshots().map((
      DocumentSnapshot<Map<String, Object?>> doc,
    ) {
      if (!doc.exists) return null;
      final TahajjudPresence presence = TahajjudPresence.fromDoc(doc);
      return presence.isExpired ? null : presence;
    });
  }

  /// Publishes the user to the map. The document id is the uid, so a user can
  /// only ever occupy one point and can always remove themselves.
  ///
  /// [place] is precise — it is reduced to a coarse cell here and the precise
  /// values never leave this method.
  Future<void> startSession({
    required NoorPlace place,
    required String displayName,
    required bool anonymous,
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('Sign in to join the Tahajjud map.');
    }
    if (_auth.isGuest) {
      throw const AppFailure(
        'Appearing on the Tahajjud map needs a full account. You can add an '
        'email and password from your profile and keep your streak.',
        code: 'guest-restricted',
      );
    }

    final String cell = Geo.encode(place.lat, place.lng);
    final ({double lat, double lng}) coarse = Geo.coarsePoint(
      place.lat,
      place.lng,
      uid,
    );
    final DateTime startedAt = DateTime.now();

    await _presence.doc(uid).set(<String, Object?>{
      'displayName': anonymous ? 'A believer' : displayName,
      'cellGeohash': cell,
      'cellLat': coarse.lat,
      'cellLng': coarse.lng,
      'countryCode': place.country,
      'startedAt': Timestamp.fromDate(startedAt),
      'expiresAt': Timestamp.fromDate(startedAt.add(kTahajjudSessionDuration)),
      'active': true,
    });
  }

  /// Removes the user from the map immediately.
  Future<void> endSession() async {
    final String? uid = _auth.uid;
    if (uid == null) return;
    await _presence.doc(uid).delete();
  }
}
