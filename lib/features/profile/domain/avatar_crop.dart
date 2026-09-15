import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../../../core/theme/app_spacing.dart';
import 'avatar.dart';

/// The geometry behind the circular crop editor, and the encoder that turns a
/// chosen region into the two JPEGs a profile picture is stored as.
///
/// None of this lives in the widget on purpose. The editor is a pinch and a
/// drag over a picture on a phone, which is the hardest thing in the app to
/// verify by looking at it — an off-by-one in the mapping from screen points
/// back to source pixels shows up as a face that is a little too far left,
/// and nobody would ever be sure. As plain functions over four numbers it can
/// be asserted exactly, which `test/avatar_crop_test.dart` does.
///
/// The model the whole file shares:
///
/// * The picture is laid out inside the viewport with `BoxFit.contain` and
///   centred — that is [displaySize] and the origin derived from it.
/// * The person's pinch and drag is an [InteractiveViewer] matrix on top of
///   that layout: a uniform scale and a translation, never a rotation.
/// * The crop is the square that bounds the circle, mapped back through both.
abstract final class AvatarCrop {
  /// The most the picture may be pinched in, as a multiple of the scale it
  /// starts at. Six is far past where a 1600-pixel source still has detail to
  /// give, which is deliberate: the limit should be the picture running out,
  /// not the app saying no.
  static const double zoomRange = 6;

  /// The size the picture is painted at before any pinch.
  ///
  /// `contain`, not `cover`: covering the viewport would silently zoom a wide
  /// picture in far past what the circle needs, and the person could never
  /// zoom back out to use the whole of its short side. Containing it means
  /// the starting scale is the most picture the circle can possibly hold.
  static Size displaySize({required Size source, required Size viewport}) {
    if (source.width <= 0 ||
        source.height <= 0 ||
        viewport.width <= 0 ||
        viewport.height <= 0) {
      return Size.zero;
    }
    final double fit = math.min(
      viewport.width / source.width,
      viewport.height / source.height,
    );
    return Size(source.width * fit, source.height * fit);
  }

  /// Below this the circle stops being a crop and starts being a dot. Nothing
  /// the app runs on is this small; it is here so an odd window cannot make
  /// the diameter zero and every number below it meaningless.
  static const double smallestCircle = 120;

  /// And above this it stops being a circle you frame a face in and becomes a
  /// wall. The app ships for iPad as well as iPhone — TARGETED_DEVICE_FAMILY
  /// is "1,2" — and a 12.9-inch screen would otherwise get a 984-point crop
  /// circle with a 984-point button under it.
  static const double largestCircle = 420;

  /// The circle, as large as the screen can hold it.
  ///
  /// The circle sits in the middle of the screen while the chrome sits at its
  /// ends, so the vertical room is the screen less *twice* the taller of the
  /// two pieces of chrome — reserving it on one side only would let the
  /// circle slide under the button on the other.
  ///
  /// Here rather than in the widget because it is arithmetic over four
  /// numbers, and arithmetic is the part of a layout that can be asserted
  /// exactly instead of looked at on one phone.
  /// [topChrome] and [bottomChrome] are measured at the app's normal text
  /// size and grown by [textScale] here, because Dynamic Type rather than
  /// screen size is what actually runs a screen with no scroll view out of
  /// room: at 1.3x the heading and the line under it take half as much room
  /// again. Scaling the whole block is a little pessimistic — the button and
  /// the paddings inside it do not grow — and pessimistic is the side of this
  /// to be wrong on, because being wrong the other way puts the circle
  /// underneath the text.
  static double diameterFor({
    required Size viewport,
    required EdgeInsets safe,
    required double topChrome,
    required double bottomChrome,
    double textScale = 1,
  }) {
    final double byWidth = viewport.width - Insets.page * 2;
    final double reserve = math.max(
      safe.top + topChrome * textScale,
      safe.bottom + bottomChrome * textScale,
    );
    final double byHeight = viewport.height - reserve * 2;
    return math.max(
      smallestCircle,
      math.min(math.min(byWidth, byHeight), largestCircle),
    );
  }

  /// The square that bounds the circle, in viewport coordinates.
  static Rect hole({required Size viewport, required double diameter}) =>
      Rect.fromCenter(
        center: Offset(viewport.width / 2, viewport.height / 2),
        width: diameter,
        height: diameter,
      );

  /// The smallest scale at which the picture still fills the circle.
  ///
  /// One for almost every picture: contained in a phone-shaped viewport, a
  /// portrait or square photo is already wider than the circle. It rises
  /// above one only when the picture is so much wider or taller than the
  /// screen that containing it leaves its short side shorter than the circle
  /// — a panorama, say — and then the editor simply starts further in.
  static double minScale({
    required Size source,
    required Size viewport,
    required double diameter,
  }) {
    final Size shown = displaySize(source: source, viewport: viewport);
    if (shown.isEmpty || diameter <= 0) return 1;
    return math.max(1, diameter / math.min(shown.width, shown.height));
  }

  /// The largest scale the editor allows, which is [zoomRange] beyond
  /// wherever it had to start. Expressed as a multiple rather than as a flat
  /// six so a picture forced to start at 1.8 still has somewhere to go.
  static double maxScale({
    required Size source,
    required Size viewport,
    required double diameter,
  }) =>
      minScale(source: source, viewport: viewport, diameter: diameter) *
      zoomRange;

  /// The matrix the editor opens on: the smallest scale that fills the circle,
  /// about the middle of the viewport.
  ///
  /// Scaled about the centre rather than about the top-left corner an
  /// identity matrix would use, because that is the difference between a wide
  /// photo opening on its middle and opening on its left edge.
  static Matrix4 initialTransform({
    required Size source,
    required Size viewport,
    required double diameter,
  }) {
    final double scale = minScale(
      source: source,
      viewport: viewport,
      diameter: diameter,
    );
    return _matrix(
      scale: scale,
      tx: viewport.width / 2 * (1 - scale),
      ty: viewport.height / 2 * (1 - scale),
    );
  }

  /// The part of the source picture the circle is looking at, in source
  /// pixels, clamped to the picture's own bounds.
  ///
  /// Clamped edge by edge rather than by sliding the whole square back, so a
  /// rectangle that has somehow escaped comes back as the overlap rather than
  /// as a square of somewhere else. In normal use it never fires: [constrain]
  /// keeps the circle inside the picture at every moment of the gesture.
  static Rect rectFor({
    required Size source,
    required Size viewport,
    required double diameter,
    required Matrix4 transform,
  }) {
    final Size shown = displaySize(source: source, viewport: viewport);
    if (shown.isEmpty) return Rect.zero;

    final double fit = shown.width / source.width;
    final double scale = _scaleOf(transform);
    if (fit <= 0 || scale <= 0) return Rect.zero;

    final double tx = transform.storage[12];
    final double ty = transform.storage[13];
    final Offset origin = Offset(
      (viewport.width - shown.width) / 2,
      (viewport.height - shown.height) / 2,
    );
    final Rect square = hole(viewport: viewport, diameter: diameter);

    double toSourceX(double x) => ((x - tx) / scale - origin.dx) / fit;
    double toSourceY(double y) => ((y - ty) / scale - origin.dy) / fit;

    return Rect.fromLTRB(
      toSourceX(square.left).clamp(0, source.width),
      toSourceY(square.top).clamp(0, source.height),
      toSourceX(square.right).clamp(0, source.width),
      toSourceY(square.bottom).clamp(0, source.height),
    );
  }

  /// [transform], nudged until the circle is full of picture again.
  ///
  /// `InteractiveViewer`'s own `boundaryMargin` cannot do this. It keeps the
  /// *child* over the viewport, and the child here is a viewport-sized box
  /// with the picture letterboxed inside it — so as far as it is concerned a
  /// black bar sitting in the middle of the circle is perfectly in bounds.
  /// This looks at where the picture actually is instead.
  ///
  /// Only the translation moves. The scale is clamped for safety but never
  /// used to fix a gap, because a pinch that corrected itself by zooming
  /// would fight the fingers doing the pinching.
  static Matrix4 constrain({
    required Size source,
    required Size viewport,
    required double diameter,
    required Matrix4 transform,
  }) {
    final Size shown = displaySize(source: source, viewport: viewport);
    if (shown.isEmpty) return transform;

    final double lowest = minScale(
      source: source,
      viewport: viewport,
      diameter: diameter,
    );
    final double scale = _scaleOf(transform).clamp(
      lowest,
      maxScale(source: source, viewport: viewport, diameter: diameter),
    );

    final Offset origin = Offset(
      (viewport.width - shown.width) / 2,
      (viewport.height - shown.height) / 2,
    );
    double tx = transform.storage[12];
    double ty = transform.storage[13];

    final double left = origin.dx * scale + tx;
    final double top = origin.dy * scale + ty;
    final double width = shown.width * scale;
    final double height = shown.height * scale;
    final Rect square = hole(viewport: viewport, diameter: diameter);

    if (left > square.left) {
      tx -= left - square.left;
    } else if (left + width < square.right) {
      tx += square.right - (left + width);
    }
    if (top > square.top) {
      ty -= top - square.top;
    } else if (top + height < square.bottom) {
      ty += square.bottom - (top + height);
    }

    return _matrix(scale: scale, tx: tx, ty: ty);
  }

  /// The scale out of a scale-and-translate matrix.
  ///
  /// Read straight off the first entry rather than through
  /// `getMaxScaleOnAxis`, which squares the column and takes a square root —
  /// enough floating-point dust to move a crop rectangle by a pixel. An
  /// `InteractiveViewer` never rotates or skews, so this entry is the scale.
  static double _scaleOf(Matrix4 transform) => transform.storage[0];

  static Matrix4 _matrix({
    required double scale,
    required double tx,
    required double ty,
  }) => Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, tx)
    ..setEntry(1, 3, ty);
}

/// The two JPEGs a saved profile picture is made of, base64 encoded and ready
/// to be written.
@immutable
class AvatarJpegs {
  const AvatarJpegs({required this.photo, required this.thumb});

  /// The [Avatar.side] square, for `users/{uid}.photo`.
  final String photo;

  /// The [Avatar.thumbSide] square, for `users/{uid}.photoThumb` and from
  /// there for the scoreboard every friend reads.
  final String thumb;

  /// Whether both fit the ceilings the security rules enforce.
  bool get fitsCeilings =>
      photo.length <= Avatar.maxChars && thumb.length <= Avatar.thumbMaxChars;
}

/// What [encodeAvatarCrop] is asked to do. One object because `compute` hands
/// exactly one value to the isolate.
@immutable
class AvatarCropOrder {
  const AvatarCropOrder({required this.source, required this.crop});

  /// The file the picker handed back, undecoded.
  final Uint8List source;

  /// The region to keep, in source pixels — see [AvatarCrop.rectFor].
  final Rect crop;
}

/// Thrown when the chosen file is not a picture this app can re-encode.
///
/// Carries the sentence to show rather than a code: there is one way this can
/// fail and one thing to say about it.
@immutable
class AvatarCropFailure implements Exception {
  const AvatarCropFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Cuts [AvatarCropOrder.crop] out of the source and encodes it twice.
///
/// A top-level function because it is meant to be handed to `compute`: a
/// 1600-pixel decode followed by two JPEG encodes is tens of milliseconds of
/// solid CPU, and on the UI thread that is a visible stall on the one screen
/// where the person is still holding the picture they just framed.
AvatarJpegs encodeAvatarCrop(AvatarCropOrder order) {
  final img.Image? decoded = _decodeOrNull(order.source);
  if (decoded == null) {
    throw const AvatarCropFailure(
      'That picture could not be read. Please choose another one.',
    );
  }

  // Orientation first, because everything below measures pixels. Flutter's
  // own decoder honours the EXIF orientation tag, so the picture the person
  // framed was already upright on screen — but `package:image` hands back the
  // raw pixels, and a photo taken in portrait would be cropped sideways
  // without this.
  //
  // Then the rest of the metadata is thrown away, and that is not tidiness.
  // `copyCrop` and `copyResize` clone the source's EXIF block and
  // `encodeJpg` writes it back out, so without this line everything the
  // camera recorded — the GPS fix of where the photo was taken, the minute it
  // was taken, the phone model — would be re-encoded into both stored copies.
  // The small one is published to `progress/{uid}.photo`, which every
  // accepted friend can read, so a profile picture would be quietly handing
  // out the coordinates of the place it was taken: usually somebody's home.
  // Nothing in the security rules could ever catch it either, because it is
  // sealed inside an opaque base64 string.
  //
  // It is a size question as well as a privacy one. The ceilings count the
  // whole JPEG, and a camera's metadata block — MakerNote plus its own
  // embedded preview — runs to tens of kilobytes, which is most of a
  // 128-pixel thumbnail's budget. Carried through, an ordinary photograph can
  // be refused for being too large when its pixels are nowhere near the
  // limit, and there is nothing the person could do about it: cropping
  // tighter does not shrink a passenger.
  final img.Image upright = img.bakeOrientation(decoded)..exif = img.ExifData();

  final int x = order.crop.left.round().clamp(0, upright.width - 1);
  final int y = order.crop.top.round().clamp(0, upright.height - 1);
  final int width = order.crop.width.round().clamp(1, upright.width - x);
  final int height = order.crop.height.round().clamp(1, upright.height - y);

  // Squared up before it is cut. The editor only ever asks for a square — the
  // crop is the box around a circle — but the clamps above trim each edge on
  // its own, so a rectangle that had reached past the picture comes out of
  // them wider than it is tall. Resized to a 512 square that is not a crop,
  // it is a stretch: a face saved slightly the wrong shape, silently.
  final int side = math.min(width, height);
  final int left = x + (width - side) ~/ 2;
  final int top = y + (height - side) ~/ 2;

  final img.Image cut = img.copyCrop(
    upright,
    x: left,
    y: top,
    width: side,
    height: side,
  );

  final img.Image big = img.copyResize(
    cut,
    width: Avatar.side,
    height: Avatar.side,
    interpolation: _interpolationFrom(side, Avatar.side),
  );
  // Resized from the big square rather than from the cut again: 512 down to
  // 128 is an exact four-to-one box filter, and it saves a second pass over
  // what may be a 1600-pixel region. Nothing is lost — `big` is still pixels
  // at this point, not a JPEG.
  final img.Image small = img.copyResize(
    big,
    width: Avatar.thumbSide,
    height: Avatar.thumbSide,
    interpolation: img.Interpolation.average,
  );

  return AvatarJpegs(
    photo: base64Encode(img.encodeJpg(big, quality: Avatar.quality)),
    thumb: base64Encode(img.encodeJpg(small, quality: Avatar.thumbQuality)),
  );
}

/// [encodeAvatarCrop] on a background isolate.
Future<AvatarJpegs> encodeAvatarCropOffThread(AvatarCropOrder order) =>
    compute(encodeAvatarCrop, order, debugLabel: 'Layla Pro avatar crop');

/// `package:image`'s decoder, made to answer only with a picture or nothing.
///
/// `decodeImage` returns null for a file it cannot read, but it finds the
/// format by handing the bytes to each decoder in turn to probe — and a probe
/// that reads a header longer than the file it was given runs off the end and
/// throws a `RangeError` instead. A truncated or empty file does it. Caught
/// here so this function has the one failure it documents: a sentence to show
/// somebody, rather than a range error from three packages down that the
/// caller can only report as "something went wrong".
///
/// A catch this broad is right for the same reason it is right in
/// [Avatar.provider]: the input is a file chosen from a photo library, no
/// decoder in the package promises what it throws, and every outcome here is
/// the same one — this is not a picture we can use.
img.Image? _decodeOrNull(Uint8List source) {
  try {
    return img.decodeImage(source);
  } on Object catch (error) {
    debugPrint('Layla Pro: chosen picture would not decode ($error)');
    return null;
  }
}

/// Averaging shrinks, cubic grows.
///
/// A box average is the right filter for throwing pixels away and the wrong
/// one for inventing them: zoomed in hard, the chosen region can be smaller
/// than the square it has to fill, and averaging up a 200-pixel crop to 512
/// leaves it looking like a blurred photocopy where cubic keeps an edge.
img.Interpolation _interpolationFrom(int from, int to) =>
    to < from ? img.Interpolation.average : img.Interpolation.cubic;
