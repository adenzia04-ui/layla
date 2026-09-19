import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/result.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../domain/app_user.dart';
import 'account_eraser.dart';
import 'welcome_email.dart';

final Provider<FirebaseAuth> firebaseAuthProvider = Provider<FirebaseAuth>(
  (Ref ref) => FirebaseAuth.instance,
);

final Provider<FirebaseFirestore> firestoreProvider =
    Provider<FirebaseFirestore>((Ref ref) => FirebaseFirestore.instance);

/// google_sign_in requires initialize() exactly once, before anything else on
/// the singleton. AuthRepository is const-constructed, so the memo lives here
/// rather than on an instance field.
Future<void>? _googleInit;
Future<void> _googleReady() =>
    _googleInit ??= GoogleSignIn.instance.initialize();

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
final StreamProvider<AppUser?> appUserProvider = StreamProvider<AppUser?>((
  Ref ref,
) {
  final User? user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream<AppUser?>.value(null);
  return ref.watch(authRepositoryProvider).watchUser(user.uid);
});

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

  Future<void> signIn({required String email, required String password}) async {
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
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
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
  Future<void> continueAsGuest({String fallbackName = ''}) async {
    try {
      final UserCredential credential = await _auth.signInAnonymously();
      await _seedProfile(
        uid: credential.user!.uid,
        // The journey asked "What should I call you?" two screens ago. Being
        // greeted as "Guest" afterwards reads as the app not listening.
        name: fallbackName.trim().isEmpty ? 'Guest' : fallbackName.trim(),
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
      }, SetOptions(merge: true));

      // Linking does not re-authenticate. The session's token goes on saying
      // `sign_in_provider: anonymous` until the next sign-in, and the security
      // rules read that claim to decide who may use Friends — so the whole
      // Friends surface opens up in the app while every write behind it is
      // refused. Signing in with the credential just linked mints a fresh
      // token under the real provider on the same uid, so the streak comes
      // along and Friends works now rather than after a sign-out.
      //
      // Its failure must not fail an upgrade that has already landed: the
      // account is created either way, and the rules read the linked
      // identities as a second route to the same answer.
      try {
        await _auth.signInWithCredential(credential);
      } on Object catch (error) {
        debugPrint('Layla Pro: upgraded account not re-authenticated ($error)');
      }
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// Sign in with Apple.
  ///
  /// The point of this screen is that a phone is not where the streak lives.
  /// Someone who signs in on a new phone with the same Apple ID gets their
  /// prayer history back, because the uid comes from Apple rather than from
  /// the install.
  ///
  /// Apple only ever hands over the name on the *first* authorisation. Every
  /// later sign-in returns nulls for it, so the name is taken when offered and
  /// never overwritten with a blank afterwards.
  /// [fallbackName] is used when the provider hands back no name.
  ///
  /// Apple returns givenName and familyName on the FIRST authorisation only.
  /// Every sign-in after that — including a reinstall, and including every
  /// retry while a sign-in bug is being fixed — returns null for both. So the
  /// one chance to learn someone's name from Apple is easily spent before it
  /// can ever be saved, and nothing later will offer it again.
  Future<void> signInWithApple({String fallbackName = ''}) async {
    final String rawNonce = _nonce();
    // Declared out here so the catch can describe the token Firebase refused.
    String? token;
    try {
      final AuthorizationCredentialAppleID apple =
          await SignInWithApple.getAppleIDCredential(
            scopes: <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
            // Apple embeds the SHA-256 of this in the identity token; Firebase
            // rehashes the raw value and compares. It is what stops a token
            // captured from one sign-in being replayed into another.
            nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
          );

      // Without a token there is nothing to sign in with. Caught here rather
      // than passed on, because Firebase's answer to a null token is
      // `invalid-credential` — a code that means "wrong password" everywhere
      // else in this app and sends anyone reading it down the wrong path.
      final String? idToken = apple.identityToken;
      token = idToken;
      if (idToken == null) {
        throw const AppFailure(
          'Apple did not return a sign-in token. Check that Sign in with '
          'Apple is allowed for Layla Pro in Settings, then try again.',
          code: 'apple-no-token',
        );
      }

      // AppleAuthProvider, not OAuthProvider('apple.com'). They look
      // interchangeable and are not: OAuthProvider.credential() stamps
      // `signInMethod: 'oauth'`, while the iOS plugin selects its Apple path
      // by testing `signInMethod == 'apple.com'`. The generic path is taken
      // instead, which posts an empty `access_token=` alongside the id_token —
      // and an IdP response Firebase will not accept comes back as
      // `invalid-credential`, indistinguishable from a bad token.
      //
      // It also carries the name, which Apple returns only on the very first
      // authorisation and which the generic path drops.
      final OAuthCredential credential =
          AppleAuthProvider.credentialWithIDToken(
            idToken,
            rawNonce,
            AppleFullPersonName(
              givenName: apple.givenName,
              familyName: apple.familyName,
            ),
          );

      final String name = <String?>[
        apple.givenName,
        apple.familyName,
      ].whereType<String>().join(' ').trim();

      await _completeSocialSignIn(
        credential: credential,
        name: name.trim().isEmpty ? fallbackName : name,
        email: apple.email ?? '',
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      // Backing out of the sheet is not a failure worth a red banner.
      if (error.code == AuthorizationErrorCode.canceled) return;
      throw AppFailure.from(error);
    } on FirebaseAuthException catch (error) {
      throw _socialFailure(error, 'Apple', notes: _appleNotes(token, rawNonce));
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// Sign in with Google. Same contract as Apple: the account, not the phone,
  /// is what the streak is attached to.
  /// See [signInWithApple] for what [fallbackName] is for.
  Future<void> signInWithGoogle({String fallbackName = ''}) async {
    try {
      await _googleReady();
      final GoogleSignInAccount account = await GoogleSignIn.instance
          .authenticate();
      final String? idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppFailure('Google did not return a usable sign-in.');
      }

      final String googleName = (account.displayName ?? '').trim();
      await _completeSocialSignIn(
        credential: GoogleAuthProvider.credential(idToken: idToken),
        name: googleName.isEmpty ? fallbackName : googleName,
        email: account.email,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      throw AppFailure.from(error);
    } on FirebaseAuthException catch (error) {
      throw _socialFailure(error, 'Google');
    } on Object catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// Signs the credential in, carrying a guest's history across when there is
  /// one to carry.
  ///
  /// A guest who signs in has a uid full of prayer_day documents. Linking
  /// keeps that uid, so the streak survives; signing in fresh would silently
  /// strand it under an account nobody can reach again. If the credential
  /// already belongs to another account, linking fails and the only honest
  /// move is to sign in to the account they asked for — the guest data is not
  /// mergeable, and pretending otherwise would lose whichever side we dropped.
  Future<void> _completeSocialSignIn({
    required AuthCredential credential,
    required String name,
    required String email,
  }) async {
    final User? guest = _auth.currentUser;
    UserCredential result;

    if (guest != null && guest.isAnonymous) {
      try {
        result = await guest.linkWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code != 'credential-already-in-use' &&
            error.code != 'email-already-in-use') {
          rethrow;
        }
        // `error.credential` and not the original: after a failed link the
        // first one has been consumed, and replaying it earns an
        // `invalid-credential` that looks like a broken token rather than a
        // spent one. The exception carries the usable replacement.
        result = await _auth.signInWithCredential(
          error.credential ?? credential,
        );
      }
    } else {
      result = await _auth.signInWithCredential(credential);
    }

    final User user = result.user!;
    final bool isNew = result.additionalUserInfo?.isNewUser ?? false;
    final String resolved = name.isNotEmpty
        ? name
        : (user.displayName ?? '').trim();

    if (isNew) {
      await _seedProfile(
        uid: user.uid,
        name: resolved,
        email: email.isNotEmpty ? email : (user.email ?? ''),
        isAnonymous: false,
      );
    } else {
      // An upgraded guest keeps its documents; only the account fields change.
      await userDoc(user.uid).set(<String, Object?>{
        if (resolved.isNotEmpty) 'displayName': resolved,
        if (email.isNotEmpty || user.email != null)
          'email': email.isNotEmpty ? email : user.email,
        'isAnonymous': false,
      }, SetOptions(merge: true));
    }

    if (resolved.isNotEmpty && (user.displayName ?? '').isEmpty) {
      await user.updateDisplayName(resolved);
    }
  }

  /// Turns a Firebase auth code into something true of a *social* sign-in.
  ///
  /// Firebase's codes are written for email and password, and several of them
  /// read as nonsense after an Apple or Google sheet. `invalid-credential` is
  /// the worst: [AppFailure._authMessage] renders it "Email or password is
  /// incorrect", which is shown to somebody who never typed either — so the
  /// message accuses them of a mistake they could not have made, and hides
  /// what actually went wrong.
  ///
  /// The fallback deliberately carries the raw code. An unexpected provider
  /// error is not something a person can act on in words, and the code is the
  /// one thing that makes it reportable.
  AppFailure _socialFailure(
    FirebaseAuthException error,
    String provider, {
    String notes = '',
  }) {
    // Firebase collapses audience mismatch, nonce mismatch, a malformed token
    // and an expired one into the single code `invalid-credential`, and puts
    // the reason that actually distinguishes them in `message`. Reading only
    // the code is what made this failure unfalsifiable.
    final String detail = (error.message ?? '').trim();
    final String suffix =
        <String>[
          if (notes.isNotEmpty) notes,
          if (detail.isNotEmpty) detail,
        ].isEmpty
        ? ''
        : ' [${<String>[if (notes.isNotEmpty) notes, if (detail.isNotEmpty) detail].join(' | ')}]';
    final String message = switch (error.code) {
      'invalid-credential' || 'invalid-verification-code' =>
        '$provider could not verify that sign-in. Please try again.$suffix',
      'account-exists-with-different-credential' =>
        'You already have a Layla Pro account with that email. Sign in the way '
            'you did last time, then add $provider from Account settings.',
      'operation-not-allowed' =>
        'Sign in with $provider is not switched on for this app yet.',
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' =>
        'No connection. Check your network and try again.',
      _ => 'Sign in with $provider did not complete (${error.code}).',
    };
    return AppFailure(message, code: error.code, cause: error);
  }

  /// What Apple actually put in the token, for the one failure that hides it.
  ///
  /// `invalid-credential` is Firebase declining to say *why* it would not
  /// accept a token. Only two things about the token can cause it here, and
  /// both are visible in the payload: the audience it was minted for, and
  /// whether the nonce Apple embedded matches the one being replayed. Reading
  /// them turns an unfalsifiable error into a fact.
  ///
  /// No signature check and no secrets: `aud` is a bundle identifier and the
  /// nonce is compared, never shown.
  String _appleNotes(String? token, String rawNonce) {
    if (token == null) return 'no token';
    try {
      final List<String> parts = token.split('.');
      if (parts.length != 3) return 'not a JWT';
      final Map<String, Object?> claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, Object?>;
      final String expected = sha256.convert(utf8.encode(rawNonce)).toString();
      final bool nonceOk = claims['nonce'] == expected;
      return 'aud=${claims['aud']} nonce=${nonceOk ? 'ok' : 'MISMATCH'}';
    } on Object {
      return 'token unreadable';
    }
  }

  /// A cryptographically random string for the Apple nonce.
  String _nonce([int length = 32]) {
    const String chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final Random rand = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
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
      // The documents first, while there is still a signed-in user to
      // authorise the deletes. Once `user.delete()` returns, every rule in
      // the database refuses this account's data to everyone — including
      // this phone — and whatever is left is left for good.
      //
      // This used to be left to the `onUserDeleted` Cloud Function, which
      // has never been deployed. See AccountEraser.
      final List<String> failed = await AccountEraser(_db).erase(user.uid);
      if (failed.isNotEmpty) {
        throw AppFailure(
          'Some of your data could not be removed (${failed.join(', ')}), so '
          'your account was kept. Check your connection and try again.',
        );
      }
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
  }) => userDoc(uid).set(<String, Object?>{
    // Omitted when empty, never written as ''. This is a merge onto a
    // document that may already exist — the Cloud Function auth trigger
    // creates one too — so writing an empty string here does not leave
    // the field unset, it actively erases a name that was already
    // there. Leaving the key out preserves whatever is stored.
    if (name.trim().isNotEmpty) 'displayName': name.trim(),
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
      // Present from the first write, null included. `StreakStats.fromMap`
      // falls back to `lastCompletedDate` only while this key has never been
      // written, which is how accounts older than the split keep publishing a
      // real date; a new account has nothing to migrate and must not inherit
      // that fallback.
      'lastConfirmedDate': null,
    },
  }, SetOptions(merge: true));

  /// Whether nothing anywhere knows what to call this person.
  ///
  /// True after an Apple sign-in that returned no name, which is every Apple
  /// sign-in except the very first one for that Apple ID.
  bool get needsDisplayName =>
      (_auth.currentUser?.displayName ?? '').trim().isEmpty;

  Future<void> updateDisplayName(String name) async {
    final User? user = _auth.currentUser;
    // Returning quietly here told the caller the save had worked when nothing
    // had been written anywhere — "Name updated." over an unchanged screen.
    if (user == null) {
      throw const AppFailure(
        'You are not signed in, so there is nothing to save to.',
        code: 'not-signed-in',
      );
    }
    final String clean = name.trim();

    // Firestore FIRST, because it is the copy the app actually reads — the
    // greeting, the profile and the avatar all come from the user document
    // via `watchUser`. This used to write the Firebase Auth profile first and
    // Firestore second, so anything that threw on the way in left the name
    // saved nowhere the user could see, and the screen looked broken rather
    // than errored.
    // Not waited on indefinitely. A Firestore write Future completes when the
    // SERVER acknowledges, not when the write lands — so with no connection it
    // stays pending forever while the value is already applied to the local
    // cache and queued. The snapshot listener has fired by then and the new
    // name is on screen, but the caller's `finally` never runs: the Save
    // button spins for good, with no success and no error. Given how often
    // this phone drops off the network, that is not a corner case.
    await userDoc(user.uid)
        .set(<String, Object?>{'displayName': clean}, SetOptions(merge: true))
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => debugPrint(
            'Layla Pro: name written locally, will sync when back online',
          ),
        );

    // The Auth profile is a nice-to-have — it is what other providers read
    // back on a later sign-in. Failing to set it must not undo the write the
    // person can actually see.
    //
    // Timed out for the same reason the Firestore write above is, and it was
    // missed here: this call goes to Firebase's servers and, on a bad
    // connection, neither returns nor throws. The caller is a modal sheet
    // that cannot be dismissed, so a hang here left somebody staring at a
    // spinning Save button with no error, no way back, and their name already
    // saved in the one place the app actually reads.
    try {
      await user
          .updateDisplayName(clean)
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => debugPrint(
              'Layla Pro: auth profile name timed out; the profile is saved',
            ),
          );
    } on Object catch (error) {
      debugPrint('Layla Pro: auth profile name not updated ($error)');
    }
  }

  /// Remembers on the account whether this is a brother or a sister.
  ///
  /// The onboarding answer lived in SharedPreferences alone, and
  /// `AuthController.signOut` clears that — so answering "sister" once did not
  /// survive signing out and back in, and with it went the only thing that
  /// decides whether the prayer pause is ever offered. Nothing else about the
  /// journey is worth putting on the server; this is, because losing it has a
  /// consequence the person would feel and could not explain.
  ///
  /// Only the two values the question can produce are ever written. The rules
  /// refuse a third, and a refused write is silent — it would not fail, the
  /// feature would simply never appear.
  /// Never throws. It is called on the way into an account and again on every
  /// app open, both fire-and-forget, and neither has anything useful to do
  /// with a failure — the local answer is still readable and the next open
  /// tries again. Letting it throw would turn a field that did not save into a
  /// sign-in that did not happen.
  Future<void> saveGender(String? gender) async {
    final String? id = uid;
    if (id == null || !Gender.isValid(gender)) return;
    try {
      await userDoc(
        id,
      ).set(<String, Object?>{'gender': gender}, SetOptions(merge: true));
    } on Object catch (error) {
      debugPrint('Layla Pro: gender not saved to the profile ($error)');
    }
  }

  Future<void> updateSettings(PrayerSettings settings) async {
    final String? id = uid;
    if (id == null) return;
    await userDoc(id).set(<String, Object?>{
      'settings': settings.toMap(),
    }, SetOptions(merge: true));
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
    }, SetOptions(merge: true));
  }
}
