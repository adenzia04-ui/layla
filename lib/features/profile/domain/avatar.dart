import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A profile picture, encoded small enough to live inside a Firestore
/// document.
///
/// There is no Firebase Storage on this project — the Spark plan does not
/// offer it, and `firebase_storage` is deliberately absent from pubspec — so
/// the picture travels as a base64 JPEG on `users/{uid}.photo` and, for
/// friends to read, on `progress/{uid}.photo`. That is the whole reason for
/// the ceilings below: a Firestore document is capped at roughly a megabyte
/// and the progress document has to carry a scoreboard alongside the picture,
/// so the picture is held to a size that leaves plenty of room and still costs
/// little to read on every friend's phone.
///
/// A saved picture is two JPEGs cut from the same chosen region, not one. The
/// big one is your own face on your own phone, where it is drawn at 64 points
/// and deserves to be sharp; the small one is the copy every friend's phone
/// downloads on every scoreboard read, where it is drawn at 44 points and a
/// sharper file would only be someone else's bandwidth. One picture could not
/// be both, which is why [side] and [thumbSide] exist.
///
/// The ceilings are counted in base64 characters rather than bytes because
/// that is what the security rules can measure: `size()` on a Firestore string
/// is its character count, so the client and the rules agree only if both
/// count the same thing.
abstract final class Avatar {
  /// The longest the stored avatar may be, in base64 characters. The security
  /// rules refuse anything past this, so the client must refuse it first —
  /// a rejected write is silent, and a person would be left looking at an
  /// unchanged avatar with nothing on screen to say why.
  static const int maxChars = 200000;

  /// The same ceiling for the friends' copy. Roughly an eighth of [maxChars],
  /// because a 128-pixel square is roughly an eighth of the data of a 512 —
  /// and because this one is read by every friend, every time the scoreboard
  /// moves.
  static const int thumbMaxChars = 24000;

  /// The longest side asked of the picker, to crop from.
  ///
  /// Far larger than anything that is stored. This is the source the person
  /// pinches and drags over, and a crop is a magnifying glass: zoom to 4x on
  /// a 512-pixel source and the stored 512 square is built from 128 real
  /// pixels. 1600 leaves the crop something to take.
  static const int pickSide = 1600;

  /// JPEG quality asked of the picker. High, because this file is only ever
  /// an intermediate — it is decoded, cropped and re-encoded before anything
  /// is stored, and compression artefacts baked in here would be magnified by
  /// the crop and then encoded a second time.
  static const int pickQuality = 90;

  /// The side of the stored avatar, in pixels. 512 is a 64-point circle at
  /// 3x with room to spare, so the picture stays sharp on the profile and on
  /// the home header of every phone the app runs on.
  static const int side = 512;

  /// JPEG quality of the stored avatar.
  static const int quality = 85;

  /// The side of the friends' copy, in pixels. 128 covers the 44-point circle
  /// a friend card draws at 3x.
  static const int thumbSide = 128;

  /// JPEG quality of the friends' copy.
  static const int thumbQuality = 80;

  /// The largest the decoder is allowed to expand a picture to, per side.
  ///
  /// [maxChars] bounds the *encoded* string and can never bound the decoded
  /// pixels: JPEG is compressed, so 48 KB of flat colour can legitimately
  /// declare 12000x12000 in its header, which Skia would expand to 576 MB of
  /// RGBA and the phone would kill the app for. Nothing in the app writes
  /// such a picture — but a friend's `progress/{uid}.photo` is written by
  /// their phone, not yours, and it is decoded on yours the moment their card
  /// is built. Twice [side] leaves an honest avatar untouched at every size
  /// the app draws and caps the dishonest one at a few megabytes.
  static const int maxDecodeSide = 1024;

  /// How many decoded pictures to keep.
  ///
  /// Sized to the whole friends list rather than to a screenful, because the
  /// list is not lazy — `friends_screen.dart` builds every card in one pass,
  /// so a cache smaller than the list evicts entries inserted earlier in the
  /// same frame and every avatar misses on the next rebuild. A miss is not
  /// only a base64 decode: it hands back a new provider, which misses in
  /// Flutter's own `ImageCache` too and blanks the circle while it re-decodes.
  static const int _cacheSize = 64;

  /// Decoded pictures, newest use last.
  ///
  /// [provider] is called from `build`, so without this every scroll frame
  /// would base64-decode a 48KB string per avatar. Failures are cached too:
  /// a malformed string must not be re-parsed on every rebuild either, and a
  /// cached null is what tells the widget to fall back to initials.
  static final Map<String, ImageProvider?> _decoded =
      <String, ImageProvider?>{};

  /// Whether [encoded] is something worth trying to draw.
  ///
  /// Oversize is treated as unusable rather than clamped: a string past
  /// [maxChars] cannot have come from this app, and drawing half a JPEG is
  /// worse than drawing initials.
  static bool isUsable(String? encoded) =>
      encoded != null && encoded.isNotEmpty && encoded.length <= maxChars;

  /// Whether [encoded] is a friends' copy worth publishing.
  ///
  /// A separate test rather than [isUsable] with a different number, because
  /// the two ceilings guard different documents: this one is what the progress
  /// scoreboard will take, and publishing a string past it is refused by the
  /// rules — silently, taking the whole scoreboard write down with it.
  static bool isUsableThumb(String? encoded) =>
      encoded != null && encoded.isNotEmpty && encoded.length <= thumbMaxChars;

  /// An image for [encoded], or null when there is nothing usable to draw.
  ///
  /// Never throws. `base64Decode` throws on anything that is not base64, and
  /// this is called from a build method for a value that arrives from another
  /// person's Firestore document — so the decode is guarded and a failure
  /// becomes a null the caller renders initials for.
  ///
  /// The same string always hands back the same provider instance, which is
  /// what keeps an `Image` widget from re-resolving its stream on every
  /// rebuild.
  ///
  /// The provider is wrapped in a [ResizeImage] so the decode itself is
  /// bounded — see [maxDecodeSide]. `ResizeImage` passes its target through to
  /// `instantiateImageCodec`, which makes the codec sample-decode, so peak
  /// memory follows the target rather than whatever the file's header claims.
  /// A widget's `width` and `height` cannot do this: those are layout, applied
  /// long after the pixels exist.
  static ImageProvider? provider(String? encoded) {
    if (!isUsable(encoded)) return null;
    final String key = encoded!;

    if (_decoded.containsKey(key)) {
      // Re-inserted so the map's insertion order is least-recently-used
      // first, which is what the eviction below relies on.
      final ImageProvider? hit = _decoded.remove(key);
      _decoded[key] = hit;
      return hit;
    }

    ImageProvider? image;
    try {
      final Uint8List bytes = base64Decode(key);
      image = bytes.isEmpty
          ? null
          : ResizeImage(
              MemoryImage(bytes),
              width: maxDecodeSide,
              height: maxDecodeSide,
              // Fit, not the default stretch-to-both: a picture that is not
              // square keeps its shape, and `BoxFit.cover` crops it the same
              // way it always did.
              policy: ResizeImagePolicy.fit,
              // A 64-pixel picture must not be blown up to 512 to be drawn in
              // a 44-point circle.
              allowUpscaling: false,
            );
    } on Object catch (error) {
      debugPrint('Layla Pro: profile picture could not be decoded ($error)');
      image = null;
    }

    _decoded[key] = image;
    if (_decoded.length > _cacheSize) _decoded.remove(_decoded.keys.first);
    return image;
  }

  /// Forgets every decoded picture. For tests; the app has no reason to.
  @visibleForTesting
  static void clearCache() => _decoded.clear();
}
