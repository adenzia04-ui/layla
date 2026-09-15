import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noor/features/profile/domain/avatar.dart';
import 'package:noor/features/profile/domain/avatar_crop.dart';

/// The crop editor's arithmetic, asserted rather than eyeballed.
///
/// This is the part of the avatar feature that cannot be checked by looking at
/// it. A mistake in the mapping from screen points back to source pixels does
/// not crash and does not look broken — it produces a face that is slightly
/// off-centre, or a picture that is quietly a little more zoomed than the
/// circle showed, and nobody would ever be certain enough to file it. Exact
/// rectangles are the only honest test.
///
/// The model under test, restated so the numbers below can be followed: the
/// picture is contained in the viewport and centred, the pinch is a scale and
/// a translation on top of that, and the crop is the square bounding the
/// circle mapped back through both.
void main() {
  group('AvatarCrop.rectFor', () {
    // A square picture contained in a 400x800 viewport is painted 400x400 and
    // centred, so a 400-point circle sits exactly on it: whatever comes back
    // from these tests is measured against a picture whose every edge is
    // visible at rest.
    const Size square = Size(1000, 1000);
    const Size viewport = Size(400, 800);
    const double diameter = 400;

    test('at rest, the circle holds the whole picture', () {
      expectRect(
        AvatarCrop.rectFor(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: Matrix4.identity(),
        ),
        const Rect.fromLTRB(0, 0, 1000, 1000),
      );
    });

    test('pinched to 2x, it holds a quarter of it', () {
      expectRect(
        AvatarCrop.rectFor(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: view(scale: 2, about: viewport),
        ),
        // Half the width and half the height, about the middle.
        const Rect.fromLTRB(250, 250, 750, 750),
      );
    });

    test('dragging the picture moves what the circle is looking at', () {
      // 40 points to the right, at 2x on a picture painted at 0.4 of its own
      // size, is 40 / (2 * 0.4) = 50 source pixels to the left.
      final Matrix4 dragged = view(scale: 2, about: viewport)..translateX(40);
      expectRect(
        AvatarCrop.rectFor(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: dragged,
        ),
        const Rect.fromLTRB(200, 250, 700, 750),
      );
    });

    test('dragged past the edge, it clamps to the picture', () {
      // Far enough right that the circle's left half is off the picture. The
      // rectangle is clipped to the overlap rather than slid back, so what
      // comes out is still a region of this picture and never of nowhere.
      final Matrix4 dragged = view(scale: 2, about: viewport)..translateX(400);
      expectRect(
        AvatarCrop.rectFor(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: dragged,
        ),
        const Rect.fromLTRB(0, 250, 250, 750),
      );
    });

    test('a 16:9 picture opens on a centred square of its full height', () {
      const Size wide = Size(1600, 900);
      const double circle = 350;
      expectRect(
        AvatarCrop.rectFor(
          source: wide,
          viewport: viewport,
          diameter: circle,
          transform: AvatarCrop.initialTransform(
            source: wide,
            viewport: viewport,
            diameter: circle,
          ),
        ),
        // 900 across, the whole of the short side, centred in the long one.
        const Rect.fromLTRB(350, 0, 1250, 900),
      );
    });

    test('a 9:16 picture opens on a centred square of its full width', () {
      const Size tall = Size(900, 1600);
      // A landscape window, so the tall picture is the one running out of
      // room — the mirror of the case above, and the reason the minimum scale
      // is worked out from both sides rather than from the width alone.
      const Size landscape = Size(800, 400);
      const double circle = 350;
      expectRect(
        AvatarCrop.rectFor(
          source: tall,
          viewport: landscape,
          diameter: circle,
          transform: AvatarCrop.initialTransform(
            source: tall,
            viewport: landscape,
            diameter: circle,
          ),
        ),
        const Rect.fromLTRB(0, 350, 900, 1250),
      );
    });

    test('a picture with no pixels asks for nothing', () {
      expect(
        AvatarCrop.rectFor(
          source: Size.zero,
          viewport: viewport,
          diameter: diameter,
          transform: Matrix4.identity(),
        ),
        Rect.zero,
      );
    });
  });

  group('AvatarCrop.minScale', () {
    const Size viewport = Size(400, 800);

    test('a portrait picture already covers the circle, so it opens at 1', () {
      expect(
        AvatarCrop.minScale(
          source: const Size(750, 1000),
          viewport: viewport,
          diameter: 350,
        ),
        1,
      );
    });

    test('a wide picture has to open further in', () {
      // Contained, a 16:9 picture is 400x225 in this viewport — 125 points
      // short of the circle, which is exactly what it has to make up.
      expect(
        AvatarCrop.minScale(
          source: const Size(1600, 900),
          viewport: viewport,
          diameter: 350,
        ),
        moreOrLessEquals(350 / 225, epsilon: 1e-9),
      );
    });

    test('the zoom range is measured from wherever it had to start', () {
      const Size wide = Size(1600, 900);
      expect(
        AvatarCrop.maxScale(source: wide, viewport: viewport, diameter: 350),
        moreOrLessEquals(350 / 225 * AvatarCrop.zoomRange, epsilon: 1e-9),
      );
    });
  });

  group('AvatarCrop.diameterFor', () {
    // The reservations the crop screen passes in, at the app's normal text
    // size. Copied rather than imported so that a change to the screen shows
    // up here as a disagreement rather than as two numbers moving together.
    const double top = 151;
    const double bottom = 103;

    test('on a phone the width is what runs out first', () {
      // Every phone the app supports is far taller than it is wide, so the
      // circle is the page width and nothing else — 20 points of margin
      // either side.
      expect(
        AvatarCrop.diameterFor(
          viewport: const Size(375, 667),
          safe: EdgeInsets.zero,
          topChrome: top,
          bottomChrome: bottom,
        ),
        335,
      );
    });

    test('a tablet gets a circle, not a wall', () {
      // TARGETED_DEVICE_FAMILY is "1,2" and portrait is allowed for iPad, so
      // this really is reachable: without the cap a 12.9-inch screen draws a
      // 984-point crop circle, which is not a face-framing circle, it is the
      // screen.
      expect(
        AvatarCrop.diameterFor(
          viewport: const Size(1024, 1366),
          safe: EdgeInsets.zero,
          topChrome: top,
          bottomChrome: bottom,
        ),
        AvatarCrop.largestCircle,
      );
    });

    test('Dynamic Type takes room from the circle, not from the heading', () {
      // The chrome is text, and at 1.3x there is half as much of it again.
      // The circle is what has to give: it is the only thing on the screen
      // that can.
      final double normal = AvatarCrop.diameterFor(
        viewport: const Size(375, 667),
        safe: EdgeInsets.zero,
        topChrome: top,
        bottomChrome: bottom,
      );
      final double large = AvatarCrop.diameterFor(
        viewport: const Size(375, 667),
        safe: EdgeInsets.zero,
        topChrome: top,
        bottomChrome: bottom,
        textScale: 1.3,
      );
      expect(large, lessThan(normal));
      // Twice the reservation plus the circle is the whole screen, which is
      // what keeps the circle off the text at either end.
      expect(large, moreOrLessEquals(667 - 2 * top * 1.3, epsilon: 0.001));
    });

    test('a window too small to crop in still has a circle in it', () {
      // Nothing the app runs on is this shape. What matters is that the
      // diameter cannot come out zero or negative and make every number
      // derived from it meaningless.
      expect(
        AvatarCrop.diameterFor(
          viewport: const Size(200, 200),
          safe: EdgeInsets.zero,
          topChrome: top,
          bottomChrome: bottom,
        ),
        AvatarCrop.smallestCircle,
      );
    });
  });

  group('AvatarCrop.constrain', () {
    const Size viewport = Size(400, 800);
    const double diameter = 400;

    test('a gap in the circle is closed by moving the picture back', () {
      const Size square = Size(1000, 1000);
      // Dragged far enough right that the circle is half empty.
      final Matrix4 dragged = view(scale: 2, about: viewport)..translateX(400);
      final Matrix4 fixed = AvatarCrop.constrain(
        source: square,
        viewport: viewport,
        diameter: diameter,
        transform: dragged,
      );
      // Back to the picture's own left edge under the circle's, and no
      // further: the drag is honoured as far as it can be.
      expectRect(
        AvatarCrop.rectFor(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: fixed,
        ),
        const Rect.fromLTRB(0, 250, 500, 750),
      );
    });

    test('a pinch below the minimum is held at the minimum', () {
      const Size wide = Size(1600, 900);
      final Matrix4 fixed = AvatarCrop.constrain(
        source: wide,
        viewport: viewport,
        diameter: 350,
        transform: Matrix4.identity(),
      );
      expect(
        fixed.storage[0],
        moreOrLessEquals(
          AvatarCrop.minScale(source: wide, viewport: viewport, diameter: 350),
          epsilon: 1e-9,
        ),
      );
      // And the circle is full of picture again, which is the whole point.
      final Rect crop = AvatarCrop.rectFor(
        source: wide,
        viewport: viewport,
        diameter: 350,
        transform: fixed,
      );
      expect(crop.width, moreOrLessEquals(900, epsilon: 1e-9));
      expect(crop.height, moreOrLessEquals(900, epsilon: 1e-9));
    });

    test('a view already covering the circle is left exactly alone', () {
      const Size square = Size(1000, 1000);
      final Matrix4 resting = view(scale: 2, about: viewport);
      expect(
        AvatarCrop.constrain(
          source: square,
          viewport: viewport,
          diameter: diameter,
          transform: resting,
        ),
        resting,
      );
    });
  });

  group('encodeAvatarCrop', () {
    // Encoded once: building a 1200x900 picture pixel by pixel and JPEG-ing
    // it is the slow part, and every test below wants the same one.
    late final Uint8List source = _photograph(width: 1200, height: 900);

    test('a crop becomes both sizes, and both decode square', () {
      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: source,
          crop: const Rect.fromLTWH(150, 0, 900, 900),
        ),
      );

      final img.Image? big = img.decodeJpg(base64Decode(jpegs.photo));
      final img.Image? small = img.decodeJpg(base64Decode(jpegs.thumb));

      expect(big, isNotNull);
      expect(<int>[big!.width, big.height], <int>[Avatar.side, Avatar.side]);
      expect(small, isNotNull);
      expect(
        <int>[small!.width, small.height],
        <int>[Avatar.thumbSide, Avatar.thumbSide],
      );
    });

    test('both fit under the ceilings the rules enforce', () {
      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: source,
          crop: const Rect.fromLTWH(150, 0, 900, 900),
        ),
      );
      // Printed because the margin is the interesting number: if a detailed
      // picture ever creeps up on a ceiling, this is where it will show.
      debugPrint(
        'avatar ${jpegs.photo.length}/${Avatar.maxChars}, '
        'thumb ${jpegs.thumb.length}/${Avatar.thumbMaxChars}',
      );
      expect(jpegs.photo.length, lessThan(Avatar.maxChars));
      expect(jpegs.thumb.length, lessThan(Avatar.thumbMaxChars));
      expect(jpegs.fitsCeilings, isTrue);
      // The small copy really is much smaller — that is the reason it exists.
      expect(jpegs.thumb.length, lessThan(jpegs.photo.length ~/ 4));
    });

    test('a crop reaching past the picture is pulled back inside it', () {
      // The editor never asks for this; a rounding error at the very edge
      // could. What must not happen is a throw inside the isolate.
      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: source,
          crop: const Rect.fromLTWH(1100, 800, 900, 900),
        ),
      );
      expect(img.decodeJpg(base64Decode(jpegs.photo))!.width, Avatar.side);
    });

    test('something that is not a picture fails with a sentence', () {
      expect(
        () => encodeAvatarCrop(
          AvatarCropOrder(
            source: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]),
            crop: const Rect.fromLTWH(0, 0, 10, 10),
          ),
        ),
        throwsA(
          isA<AvatarCropFailure>().having(
            (AvatarCropFailure f) => f.message,
            'message',
            contains('choose another'),
          ),
        ),
      );
    });

    test('nothing the camera wrote survives into either copy', () {
      // The reason this is a test and not a comment: nothing about a stored
      // picture looks different when it carries the photographer's GPS fix.
      // It is sealed inside base64, the rules cannot see into it, and the
      // small copy is published to `progress/{uid}.photo`, which every
      // accepted friend can read — so a regression here hands out the
      // coordinates of somebody's home and nobody finds out.
      final Uint8List carrying = _photographWithExif(width: 1200, height: 900);

      // The source really is carrying it, or the assertions below prove
      // nothing at all.
      expect(img.decodeJpg(carrying)!.exif.isEmpty, isFalse);

      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: carrying,
          crop: const Rect.fromLTWH(150, 0, 900, 900),
        ),
      );

      expect(img.decodeJpg(base64Decode(jpegs.photo))!.exif.isEmpty, isTrue);
      expect(img.decodeJpg(base64Decode(jpegs.thumb))!.exif.isEmpty, isTrue);
    });

    test('a fat metadata block does not eat the ceilings', () {
      // A camera's own metadata — MakerNote plus the preview thumbnail it
      // embeds — runs to tens of kilobytes, and the ceilings count the whole
      // JPEG file rather than its pixels. Carried through, that block alone
      // was most of a 128-pixel thumbnail's budget and could push an ordinary
      // photograph over a limit its pixels were nowhere near, leaving the
      // person told to "choose another one" with nothing they could change.
      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: _photographWithExif(
            width: 1200,
            height: 900,
            makerNoteBytes: 24000,
          ),
          crop: const Rect.fromLTWH(150, 0, 900, 900),
        ),
      );
      expect(jpegs.fitsCeilings, isTrue);
      expect(jpegs.thumb.length, lessThan(Avatar.thumbMaxChars));
    });

    test('a region that is not square is squared up, never stretched', () {
      // The editor only ever asks for a square, but the encoder clamps each
      // edge of the order on its own, so an order that reached past the
      // picture can come out of the clamps wider than it is tall. Handed to a
      // 512-by-512 resize, that is not a crop, it is a stretch — a face saved
      // the wrong shape, silently and forever.
      //
      // 400 wide by 900 tall from y=400 of a 900-tall picture: 500 of the
      // height survives the clamp, 400 of the width does, and the square that
      // should be cut is the middle 400 of both.
      final AvatarJpegs jpegs = encodeAvatarCrop(
        AvatarCropOrder(
          source: _marked(width: 1200, height: 900),
          crop: const Rect.fromLTWH(100, 400, 400, 900),
        ),
      );

      // The mark is a 100-pixel square in the source. Stretched, it comes out
      // as a rectangle a fifth taller than it is wide; cut square, it comes
      // out square, which is the whole assertion.
      final Rect mark = _markIn(img.decodeJpg(base64Decode(jpegs.photo))!);
      expect(mark.width, greaterThan(100));
      expect(
        mark.height,
        moreOrLessEquals(mark.width, epsilon: 4),
        reason:
            'the mark came back ${mark.width} by ${mark.height} — the region '
            'was resized to a square without being cut as one.',
      );
    });

    test('a file too short to hold a header fails the same way', () {
      // Not the same case as the one above, though it reads like it. Eight
      // bytes are enough for every decoder to look at and reject, and
      // `decodeImage` answers null. Five are not: a decoder probing for a
      // header longer than the file reads off the end and throws a
      // `RangeError` from inside `package:image` instead. A truncated
      // download is exactly that file, and before this was caught the person
      // was told "could not be saved" — a fault in the app — rather than
      // "could not be read", which is the one thing they can act on.
      expect(
        () => encodeAvatarCrop(
          AvatarCropOrder(
            source: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
            crop: const Rect.fromLTWH(0, 0, 10, 10),
          ),
        ),
        throwsA(isA<AvatarCropFailure>()),
      );
      expect(
        () => encodeAvatarCrop(
          AvatarCropOrder(
            source: Uint8List(0),
            crop: const Rect.fromLTWH(0, 0, 10, 10),
          ),
        ),
        throwsA(isA<AvatarCropFailure>()),
      );
    });
  });

  // The path the app actually takes. Everything above calls the encoder
  // directly, on this thread, which is not how a single picture is ever saved
  // — `_use` hands the order to `compute`. An order that cannot cross an
  // isolate boundary, or a failure that does not survive the crossing, would
  // break every save on a real phone with every test above still green, so
  // the crossing itself is asserted here.
  group('encodeAvatarCropOffThread', () {
    test('an order crosses to the isolate and the JPEGs come back', () async {
      final AvatarJpegs jpegs = await encodeAvatarCropOffThread(
        AvatarCropOrder(
          source: _photograph(width: 600, height: 400),
          crop: const Rect.fromLTWH(100, 0, 400, 400),
        ),
      );

      // `Rect` is the part that has to survive the hop: it is the only field
      // of the order that is not a list of bytes, and a crop that arrived as
      // zero would come back as a picture of the top-left corner.
      final img.Image? big = img.decodeJpg(base64Decode(jpegs.photo));
      expect(big, isNotNull);
      expect(<int>[big!.width, big.height], <int>[Avatar.side, Avatar.side]);
      expect(jpegs.fitsCeilings, isTrue);
    });

    test('a failure inside the isolate arrives as the same sentence', () async {
      await expectLater(
        encodeAvatarCropOffThread(
          AvatarCropOrder(
            source: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
            crop: const Rect.fromLTWH(0, 0, 10, 10),
          ),
        ),
        throwsA(
          isA<AvatarCropFailure>().having(
            (AvatarCropFailure f) => f.message,
            'message',
            contains('choose another'),
          ),
        ),
      );
    });
  });

  group('Avatar ceilings', () {
    test('exactly maxChars is still usable — the ceiling is inclusive', () {
      expect(Avatar.isUsable('a' * Avatar.maxChars), isTrue);
    });

    test('one character past maxChars is not', () {
      expect(Avatar.isUsable('a' * (Avatar.maxChars + 1)), isFalse);
    });

    test('the friends copy is held to its own, smaller ceiling', () {
      expect(Avatar.isUsableThumb('a' * Avatar.thumbMaxChars), isTrue);
      expect(Avatar.isUsableThumb('a' * (Avatar.thumbMaxChars + 1)), isFalse);
      // A string the big field would happily take, which this one must not:
      // the two ceilings guard two different documents.
      expect(Avatar.isUsable('a' * (Avatar.thumbMaxChars + 1)), isTrue);
    });

    test('nothing is never usable, at either size', () {
      expect(Avatar.isUsable(null), isFalse);
      expect(Avatar.isUsable(''), isFalse);
      expect(Avatar.isUsableThumb(null), isFalse);
      expect(Avatar.isUsableThumb(''), isFalse);
    });
  });
}

/// A scale-and-translate matrix, the only shape an `InteractiveViewer` makes.
///
/// [about] scales around the middle of that viewport rather than around the
/// top-left corner, which is what a pinch with two fingers either side of the
/// circle actually does.
Matrix4 view({required double scale, Size? about}) {
  final double tx = about == null ? 0 : about.width / 2 * (1 - scale);
  final double ty = about == null ? 0 : about.height / 2 * (1 - scale);
  return Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}

extension on Matrix4 {
  /// Slides the picture sideways by [points] viewport points, the way a drag
  /// does — a change to the translation alone, leaving the scale where it is.
  void translateX(double points) => setEntry(0, 3, storage[12] + points);
}

/// Compares two rectangles edge by edge, allowing for floating-point dust.
///
/// The expected values are exact; a scale of 350/225 is not representable, so
/// an edge can land a fraction of a millionth of a pixel out. A tolerance far
/// below one pixel keeps the assertion as strict as it can honestly be.
void expectRect(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: 1e-6));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: 1e-6));
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: 1e-6));
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: 1e-6));
}

/// A generated picture with about as much detail as a real photograph.
///
/// Flat colour would prove nothing about the ceilings: JPEG would crush it to
/// a few hundred bytes and the test would pass however large the stored
/// picture had been allowed to get. This has a smooth gradient for the easy
/// part, a grid for edges, and seeded noise for the part JPEG hates — which
/// makes the encoded length here a pessimistic stand-in for a face.
Uint8List _photograph({required int width, required int height}) {
  final img.Image picture = img.Image(width: width, height: height);
  final math.Random noise = math.Random(7);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int grid = (x % 40 < 2 || y % 40 < 2) ? 60 : 0;
      picture.setPixelRgb(
        x,
        y,
        (x * 255 ~/ width + grid + noise.nextInt(40)).clamp(0, 255),
        (y * 255 ~/ height + grid + noise.nextInt(40)).clamp(0, 255),
        (((x + y) * 255) ~/ (width + height) + noise.nextInt(40)).clamp(0, 255),
      );
    }
  }
  return img.encodeJpg(picture, quality: Avatar.pickQuality);
}

/// [_photograph], with the kind of EXIF block a phone camera writes.
///
/// The tags are the ones that matter rather than a full camera's worth: where
/// the picture was taken, when, and on what. [makerNoteBytes] stands in for
/// the part that is actually large — a manufacturer's private block and the
/// preview image embedded beside it.
Uint8List _photographWithExif({
  required int width,
  required int height,
  int makerNoteBytes = 0,
}) {
  final img.Image picture = img.decodeJpg(
    _photograph(width: width, height: height),
  )!;
  picture.exif.imageIfd['Make'] = img.IfdValueAscii('LaylaProbeCamera');
  picture.exif.imageIfd['Model'] = img.IfdValueAscii('Probe One');
  picture.exif.exifIfd['DateTimeOriginal'] = img.IfdValueAscii(
    '2026:09:15 01:23:45',
  );
  picture.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(51, 1);
  picture.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(0, 1);
  if (makerNoteBytes > 0) {
    picture.exif.imageIfd['MakerNote'] = img.IfdValueUndefined.list(
      Uint8List(makerNoteBytes),
    );
  }
  return img.encodeJpg(picture, quality: Avatar.pickQuality);
}

/// A black picture with one white square in it, for asking where a crop
/// actually landed and what shape it came out.
Uint8List _marked({required int width, required int height}) {
  final img.Image picture = img.Image(width: width, height: height);
  img.fill(picture, color: img.ColorRgb8(0, 0, 0));
  img.fillRect(
    picture,
    x1: 150,
    y1: 500,
    x2: 249,
    y2: 599,
    color: img.ColorRgb8(255, 255, 255),
  );
  return img.encodeJpg(picture, quality: Avatar.pickQuality);
}

/// The bounding box of the white mark in [picture].
///
/// Thresholded well above black rather than tested for pure white: JPEG rings
/// around a hard edge, so the mark arrives with a soft border either side of
/// it. Half brightness puts the boundary in the middle of that ramp, which is
/// where the edge was.
Rect _markIn(img.Image picture) {
  int left = picture.width;
  int top = picture.height;
  int right = -1;
  int bottom = -1;
  for (int y = 0; y < picture.height; y++) {
    for (int x = 0; x < picture.width; x++) {
      if (picture.getPixel(x, y).r < 128) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}
