import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/avatar.dart';
import '../domain/avatar_crop.dart';
import '../presentation/avatar_crop_screen.dart';

/// Choosing and clearing your own profile picture, with the busy and error
/// state the profile screen needs.
///
/// `pickAndSave` hands back true only when a picture was actually stored.
/// False means one of two things and the state says which: `state.hasError` is
/// a failure worth showing, anything else is the person backing out of the
/// picker, which is not an error and must not be reported as one.
final NotifierProvider<AvatarController, AsyncValue<void>>
avatarControllerProvider = NotifierProvider<AvatarController, AsyncValue<void>>(
  AvatarController.new,
);

class AvatarController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  AuthRepository get _auth => ref.read(authRepositoryProvider);

  /// How long to wait for Firestore before calling the write done.
  ///
  /// The same eight seconds `updateDisplayName` waits. A Firestore write
  /// completes on server acknowledgement, not when the value lands, so with no
  /// connection it stays pending forever while the picture is already in the
  /// local cache and on screen — and the caller's spinner would never stop.
  static const Duration _writeTimeout = Duration(seconds: 8);

  /// Opens the photo library, lets the person frame what they chose, and
  /// stores it.
  ///
  /// Takes a [context] because the middle step is a screen. The alternative
  /// was to split this in three and leave the profile screen holding the
  /// picker's failures, which are the fiddliest part of the whole flow — a
  /// refused photo-library prompt is not an error, a cancelled crop is not an
  /// error, and only one of the two leaves anything to say.
  ///
  /// A guest may set one: `users/{uid}` is their own document either way, and
  /// a picture is one of the few things that makes the app feel theirs before
  /// they commit to an account. Signed out there is no document to write to,
  /// so nothing happens at all.
  Future<bool> pickAndSave(BuildContext context) async {
    final String? uid = _auth.uid;
    if (uid == null) return false;

    state = const AsyncValue<void>.loading();
    try {
      // Asked for large now, not small. What comes back is no longer the
      // thing that gets stored — it is the thing the person crops, and a crop
      // is a magnifying glass: every bit of zoom spends source pixels. The
      // picker still does the work of getting a 12 megapixel original down to
      // something a phone can decode without complaint.
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: Avatar.pickSide.toDouble(),
        maxHeight: Avatar.pickSide.toDouble(),
        imageQuality: Avatar.pickQuality,
      );
      if (file == null) {
        state = const AsyncValue<void>.data(null);
        return false;
      }

      final Uint8List bytes = await file.readAsBytes();
      if (!context.mounted) {
        state = const AsyncValue<void>.data(null);
        return false;
      }

      // Null means they backed out of the editor, which is a cancel exactly
      // the way backing out of the picker is.
      final AvatarJpegs? jpegs = await cropAvatar(context, source: bytes);
      if (jpegs == null) {
        state = const AsyncValue<void>.data(null);
        return false;
      }

      // Refused here rather than discovered at the rules. A write past a
      // ceiling comes back as a bare permission error, which tells the person
      // nothing they can act on. In practice it cannot happen — a 512 square
      // at quality 85 is a fraction of the ceiling — so this is the guard for
      // the picture nobody predicted.
      if (!jpegs.fitsCeilings) {
        throw const AppFailure(
          'That picture is too large to save. Please choose another one.',
          code: 'avatar-too-large',
        );
      }

      await _write(uid, photo: jpegs.photo, thumb: jpegs.thumb);
      state = const AsyncValue<void>.data(null);
      return true;
    } on PlatformException catch (error, stack) {
      // The picker reports its own failures as PlatformExceptions, and
      // AppFailure.from has no branch for them — every one of these would
      // otherwise come out as "Something went wrong. Please try again.", which
      // is exactly wrong for the common case: a refused photo-library prompt
      // is not a fault, it is a permission the person can grant.
      state = AsyncValue<void>.error(
        AppFailure(_pickerMessage(error.code), code: error.code, cause: error),
        stack,
      );
      return false;
    } on Object catch (error, stack) {
      state = AsyncValue<void>.error(AppFailure.from(error), stack);
      return false;
    }
  }

  /// Plain sentences for the ways the photo library can refuse.
  static String _pickerMessage(String code) => switch (code) {
    'photo_access_denied' =>
      'Layla Pro needs permission to open your photos. You can allow it in '
          'Settings.',
    'invalid_image' =>
      'That file is not a picture Layla Pro can use. Please choose another '
          'one.',
    'already_active' => 'Your photos are already open. Please try again.',
    _ => 'Your photos could not be opened. Please try again.',
  };

  /// Puts the profile back to initials.
  ///
  /// Written as an explicit null rather than `FieldValue.delete()`: the field
  /// is documented as "absent or null means no picture", both the rules and
  /// `AppUser.fromDoc` read it that way, and a null is one plain value to
  /// reason about in a merge that may run against a document written by an
  /// older build.
  Future<void> remove() async {
    final String? uid = _auth.uid;
    if (uid == null) return;

    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() => _write(uid, photo: null, thumb: null));
  }

  /// Merges the picture onto the user document. Merge, not replace: this
  /// document holds the name, the settings and the stats too.
  ///
  /// Both sizes in one write, always. They are one picture, and a document
  /// left holding a new face beside an old thumbnail would show a friend
  /// somebody else — for as long as it took the second write to land, or
  /// forever if it never did.
  Future<void> _write(
    String uid, {
    required String? photo,
    required String? thumb,
  }) => _auth
      .userDoc(uid)
      .set(<String, Object?>{
        'photo': photo,
        'photoThumb': thumb,
      }, SetOptions(merge: true))
      .timeout(
        _writeTimeout,
        onTimeout: () => debugPrint(
          'Layla Pro: profile picture written locally, will sync when back '
          'online',
        ),
      );
}
