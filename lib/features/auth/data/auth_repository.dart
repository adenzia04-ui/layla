import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/result.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../domain/app_user.dart';
import 'welcome_email.dart';

final Provider<FirebaseAuth> firebaseAuthProvider =
    Provider<FirebaseAuth>((Ref ref) => FirebaseAuth.instance);

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (Ref ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

/// Raw Firebase auth state — the router listens to this.
final StreamProvider<User?> authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// The signed-in user's Firestore profile, live.
final StreamProvider<AppUser?> appUserProvider = StreamProvider<AppUser?>(
  (Ref ref) {
    final User? user = ref.watch(authStateProvider).value;
    if (user == null) return Stream<AppUser?>.value(null);
    return ref.watch(authRepositoryProvider).watchUser(user.uid);
  },
);

class AuthRepository {
  const AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  User? get currentUser => _auth.currentUser;
  String? get uid => _auth.currentUser?.uid;
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  DocumentReference<Map<String, Object?>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Stream<AppUser?> watchUser(String uid) => userDoc(uid).snapshots().map(
        (DocumentSnapshot<Map<String, Object?>> doc) =>
            doc.exists ? AppUser.fromDoc(doc) : null,
      );

  // ── Sign in / up ──────────────────────────────────────────────────────

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await _seedProfile(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        isAnonymous: false,
      );
      // Not awaited: the greeting must never hold up getting into the app,
      // and its failure must never fail the sign-up.
      unawaited(const WelcomeEmail().sendFor(credential.user!));
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// "Continue without an account". Anonymous users get a real uid, so prayer
  /// times, Qibla, Tasbih and streaks all work — but the account is tied to
  /// this install only, and posting stories or appearing on the Tahajjud map
  /// is blocked until they upgrade.
  Future<void> continueAsGuest() async {
    try {
      final UserCredential credential = await _auth.signInAnonymously();
      await _seedProfile(
        uid: credential.user!.uid,
        name: 'Guest',
        email: '',
        isAnonymous: true,
      );
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// Upgrades a guest to a permanent account without losing their streak —
  /// the uid is preserved, so every prayer_day document carries over.
  Future<void> upgradeGuest({
    required String name,
    required String email,
    required String password,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AppFailure('You already have an account.');
    }
    try {
      final AuthCredential credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await user.linkWithCredential(credential);
      await user.updateDisplayName(name.trim());
      await userDoc(user.uid).set(<String, Object?>{
        'displayName': name.trim(),
        'email': email.trim(),
        'isAnonymous': false,
        'upgradedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true),);
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    try {
      // The user document and its subcollections are removed by the
      // `onUserDeleted` Cloud Function so nothing is orphaned.
      await user.delete();
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  // ── Profile writes ────────────────────────────────────────────────────

  Future<void> _seedProfile({
    required String uid,
    required String name,
    required String email,
    required bool isAnonymous,
  }) =>
      userDoc(uid).set(<String, Object?>{
        'displayName': name,
        'email': email,
        'isAnonymous': isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
        'settings': const PrayerSettings().toMap(),
        'stats': const <String, Object?>{
          'currentStreak': 0,
          'longestStreak': 0,
          'totalPrayers': 0,
          'totalTahajjud': 0,
          'lastCompletedDate': null,
        },
      }, SetOptions(merge: true),);

  Future<void> updateDisplayName(String name) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    await user.updateDisplayName(name.trim());
    await userDoc(user.uid)
        .set(<String, Object?>{'displayName': name.trim()}, SetOptions(merge: true));
  }

  Future<void> updateSettings(PrayerSettings settings) async {
    final String? id = uid;
    if (id == null) return;
    await userDoc(id).set(
      <String, Object?>{'settings': settings.toMap()},
      SetOptions(merge: true),
    );
  }

  /// Precise coordinates live only in the user's own document, which no other
  /// user can read. The Tahajjud map uses a coarse cell instead.
  Future<void> updateLocation(NoorPlace place) async {
    final String? id = uid;
    if (id == null) return;
    await userDoc(id).set(<String, Object?>{
      'location': <String, Object?>{
        ...place.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true),);
  }
}
