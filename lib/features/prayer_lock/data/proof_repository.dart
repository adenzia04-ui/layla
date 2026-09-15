import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../prayer_times/domain/prayer.dart';

final Provider<ProofRepository> proofRepositoryProvider =
    Provider<ProofRepository>(
      (Ref ref) => ProofRepository(ref.watch(authRepositoryProvider)),
    );

/// Handles Step 2 of the confirmation: capturing and keeping the prayer-mat
/// photo.
///
/// **The photo never leaves the phone.** It is written to the app's private
/// Application Support directory, and Firestore stores only the local path.
///
/// This started as a Firebase Storage upload, which is the obvious design —
/// but Storage now requires a paid Blaze plan, and paying a cloud bill to
/// store a photo that (a) only its owner may ever see, (b) has no sharing
/// surface anywhere in the app, and (c) is explicitly not verification of
/// anything, would be spending money to make the feature *worse*: photos of
/// people's homes travelling to a server for no functional gain.
///
/// Keeping it local costs nothing, is strictly more private, and preserves the
/// exact enforcement rule — a prayer reaches `completed` only if this returns a
/// real path.
///
/// Trade-off, stated plainly: photos do not survive an uninstall or move to a
/// new phone. The prayer *record* and the streak do, because those live in
/// Firestore. Only the images are local.
class ProofRepository {
  const ProofRepository(this._auth);

  final AuthRepository _auth;

  static const int _maxBytes = 8 * 1024 * 1024;

  /// Photos older than this are pruned on each save, so a year of daily
  /// prayers cannot quietly fill the device.
  static const Duration _retention = Duration(days: 90);

  /// Opens the camera (or gallery). Returns null when the user backs out —
  /// which must leave the prayer unconfirmed.
  Future<XFile?> capture({required ImageSource source}) {
    return ImagePicker().pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1280,
      maxHeight: 1280,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  /// Copies the captured photo somewhere permanent and returns its path.
  ///
  /// The picker hands back a file in a temporary directory that iOS and
  /// Android are both free to delete at any moment, so copying is not
  /// optional — without it a "confirmed" prayer could end up pointing at
  /// nothing.
  ///
  /// Throws [AppFailure] on any problem; the caller must not mark the prayer
  /// complete unless this returns normally.
  Future<String> save({
    required XFile file,
    required PrayerId prayer,
    DateTime? now,
    void Function(double progress)? onProgress,
  }) async {
    final String? uid = _auth.uid;
    if (uid == null) {
      throw const AppFailure('You need to be signed in to confirm a prayer.');
    }

    final File source = File(file.path);
    if (!source.existsSync()) {
      throw const AppFailure(
        'That photo could not be read. Please take it again.',
        code: 'proof-missing',
      );
    }

    final int length = await source.length();
    if (length == 0) {
      throw const AppFailure(
        'The photo appears to be empty. Please take it again.',
        code: 'proof-empty',
      );
    }
    if (length > _maxBytes) {
      throw const AppFailure(
        'That photo is too large. Please take a new one.',
        code: 'proof-too-large',
      );
    }

    onProgress?.call(0.2);

    try {
      final DateTime moment = now ?? DateTime.now();
      final String dateId = Fmt.dayId(moment);
      final Directory dir = Directory('${(await _root()).path}/$uid/$dateId');
      await dir.create(recursive: true);

      onProgress?.call(0.6);

      final String path = '${dir.path}/${prayer.key}.jpg';
      await source.copy(path);

      // Verify rather than trust: a truncated copy would otherwise be recorded
      // as a completed prayer.
      final File saved = File(path);
      if (!saved.existsSync() || await saved.length() != length) {
        throw const AppFailure(
          'The photo did not save completely, so this prayer is not confirmed '
          'yet. Please try again.',
          code: 'proof-incomplete',
        );
      }

      onProgress?.call(1);
      unawaited(_prune(uid));
      return path;
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      debugPrint('Layla Pro: proof save failed — $error');
      throw const AppFailure(
        'The photo could not be saved. Please try again.',
        code: 'proof-write-failed',
      );
    }
  }

  /// The saved photo for a past confirmation, or null if it is gone — after an
  /// uninstall, a device change, or the retention window.
  Future<File?> fileFor(String path) async {
    final File file = File(path);
    return file.existsSync() ? file : null;
  }

  Future<Directory> _root() async {
    // Application Support, not Documents: these are private records, not files
    // the user should browse in the Files app.
    final Directory base = await getApplicationSupportDirectory();
    return Directory('${base.path}/prayer_proofs');
  }

  /// Deletes day folders older than [_retention]. Best-effort and silent —
  /// housekeeping must never break a confirmation.
  Future<void> _prune(String uid) async {
    try {
      final Directory dir = Directory('${(await _root()).path}/$uid');
      if (!dir.existsSync()) return;

      final DateTime cutoff = DateTime.now().subtract(_retention);
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is! Directory) continue;
        final DateTime? day = DateTime.tryParse(entity.path.split('/').last);
        if (day != null && day.isBefore(cutoff)) {
          await entity.delete(recursive: true);
        }
      }
    } on Object catch (error) {
      debugPrint('Layla Pro: proof pruning skipped — $error');
    }
  }
}
