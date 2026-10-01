import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../domain/mat_check.dart';
import 'mat_second_opinion.dart';

/// One frame lifted off the camera preview, on its way to be judged.
///
/// Carries the raw plane rather than a file. The live scanner looks at the
/// picture about twice a second, and the only way to get a *file* out of an
/// iOS camera is a still capture — sixty of those in a thirty-second scan
/// would mean sixty JPEGs on disk and sixty shutter sounds.
@immutable
class MatFrame {
  const MatFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.sensorOrientation,
    this.u,
    this.v,
    this.uvRowStride,
    this.uvPixelStride,
  });

  /// A single BGRA plane, exactly as the preview stream delivers it — or, on
  /// Android, the luminance plane of a YUV420 frame.
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;

  /// The two chroma planes, when the camera gives them.
  ///
  /// iOS hands over one BGRA plane and these stay null. Android gives YUV420
  /// in three, and luminance on its own is a greyscale picture — enough to
  /// see shape, blind to the colour that separates a prayer mat from the
  /// floor it is lying on. Sending them is the difference between the check
  /// seeing what the camera sees and seeing a black-and-white version of it.
  final Uint8List? u;
  final Uint8List? v;
  final int? uvRowStride;
  final int? uvPixelStride;

  /// How far the sensor sits from upright, in degrees — straight off
  /// `CameraDescription.sensorOrientation`.
  final int sensorOrientation;

  /// That rotation as an EXIF orientation, which is the vocabulary the native
  /// side turns the frame upright with.
  int get exifOrientation => switch (((sensorOrientation % 360) + 360) % 360) {
    90 => 6, // .right
    180 => 3, // .down
    270 => 8, // .left
    _ => 1, // .up
  };
}

final Provider<MatVision> matVisionProvider = Provider<MatVision>(
  (Ref ref) => MatVision(ref.watch(matSecondOpinionProvider)),
);

/// Asks the phone to classify the Step 2 photo, on the device.
///
/// Both platforms answer now, and with the same numbers: iOS runs Apple's
/// MobileCLIP-S0 image encoder through CoreML, Android runs the same
/// encoder through ONNX Runtime, and both score against the prompt vectors
/// in `mat_prompts.json`. Android answered nothing at all until then, so
/// the scanner never fired on its own and fell back to a manual shutter.
///
/// Every failure path returns [MatVerdict.unsure], which the caller treats as
/// a pass. That is deliberate: this check exists to stop someone photographing
/// the ceiling, not to stand between a person and their prayer record. An
/// older phone, a Vision hiccup, or a platform that has no bridge at all must
/// never be the reason a prayer cannot be confirmed.
class MatVision {
  const MatVision(this._claude);

  final MatSecondOpinion _claude;

  /// Longest edge of the copy sent to Claude. 640 is about 410 image tokens
  /// against the capture's ~1,640.
  static const int _sendAt = 640;

  static const MethodChannel _channel = MethodChannel(
    'com.adenzia.layla/mat_vision',
  );

  /// Whether this device can judge a photo on its own.
  ///
  /// The live scanner needs a real answer per frame, and a platform with no
  /// bridge returns no labels at all — which [MatCheck.decide] reads as
  /// [MatVerdict.unsure]. Auto-detection there would either never fire or fire
  /// on the first frame regardless of what the camera is pointed at, so the
  /// scanner asks this first and falls back to a manual capture when it is
  /// false.
  Future<bool> canScan() async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      // Android, or a build without the bridge.
      return false;
    } on Object catch (e) {
      debugPrint('Layla Pro: mat scan unavailable ($e)');
      return false;
    }
  }

  /// The verdict for one live preview frame.
  ///
  /// On-device only, and deliberately. The scanner asks this twice a second,
  /// so escalating every ambiguous frame to Claude would spend real money
  /// answering a question the next frame asks again half a second later. The
  /// frame that finally passes is re-checked with the full [inspect] before it
  /// confirms anything, so the standard a prayer is held to has not moved —
  /// only how many times it is applied.
  Future<MatVerdict> inspectFrame(MatFrame frame) async =>
      MatCheck.decideFrame(await _frameLabels(frame));

  /// The verdict on a live frame, with the number behind it — for the
  /// scanner's readout on a testing build, so a scan that will not fire can
  /// be reported as "+0.012" rather than "it does not work".
  Future<({MatVerdict verdict, double? margin})> examineFrame(
    MatFrame frame,
  ) async {
    final List<VisionLabel> labels = await _frameLabels(frame);
    return (
      verdict: MatCheck.decideFrame(labels),
      margin: MatCheck.marginOf(labels),
    );
  }

  /// The verdict plus the numbers behind it, for the test button.
  ///
  /// The margin is what the threshold is compared against, so seeing it is the
  /// only way to tell a near miss from a confident one — and the only way to
  /// report a useful number back when the check gets a real mat wrong.
  Future<({MatVerdict verdict, double? margin, String detail})> examine(
    String path,
  ) async {
    final List<VisionLabel> labels = await _labels(path);
    final MatVerdict verdict = MatCheck.decide(labels);
    double? margin;
    for (final VisionLabel l in labels) {
      if (l.label == 'clip_mat_margin') margin = l.confidence;
    }
    final String detail = labels
        .where((VisionLabel l) => l.label != 'clip_mat_margin')
        .take(3)
        .map((VisionLabel l) => '${l.label} ${l.confidence.toStringAsFixed(2)}')
        .join(', ');
    return (verdict: verdict, margin: margin, detail: detail);
  }

  /// The strict verdict on a proof photo: only a prayer mat passes.
  ///
  /// Every proof photo is shown to Claude when the endpoint is configured —
  /// not only the ambiguous ones — because a decorative rug and a prayer mat
  /// look alike to the on-device encoder and a carpet must not confirm a
  /// prayer. See [MatCheck.decideProof].
  Future<MatVerdict> inspectProof(String path) async {
    final List<VisionLabel> labels = await _labels(path);
    final double? margin = MatCheck.marginOf(labels);
    // Claude is asked only where the phone cannot settle it: between the
    // carpet floor and the scan bar, or when there is no score at all.
    final bool ask =
        _claude.available &&
        (margin == null || MatCheck.needsProofOpinion(margin));
    final MatVerdict second = ask ? await _askClaude(path) : MatVerdict.unsure;
    return MatCheck.decideProof(labels, second);
  }

  Future<MatVerdict> inspect(String path) async {
    final List<VisionLabel> labels = await _labels(path);
    final MatVerdict local = MatCheck.decide(labels);

    // Only the photos the on-device check cannot settle go to Claude. Outside
    // that band every one of the 64 measured photos was judged correctly here,
    // so sending them would be paying to be told what we already know — and
    // sending a picture of someone's home for no reason.
    if (_claude.available &&
        MatCheck.needsSecondOpinion(MatCheck.marginOf(labels))) {
      final MatVerdict second = await _askClaude(path);
      // Unsure means the call did not land. Keep the local answer rather than
      // treating a network failure as a verdict.
      if (second != MatVerdict.unsure) return second;
    }
    return local;
  }

  /// Sends a shrunk copy, falling back to the capture if the shrink fails.
  ///
  /// Claude is billed by the pixel, and the 1280px capture costs roughly four
  /// times what a 640px copy does to answer the same yes/no question. The
  /// capture stays untouched on the phone at full size — it is the person's
  /// own record of the prayer, and it is not this check's to degrade.
  Future<MatVerdict> _askClaude(String path) async {
    final Uint8List? small = await _shrink(path);
    if (small != null) return _claude.ask(small, 'image/jpeg');

    final File file = File(path);
    if (!file.existsSync()) return MatVerdict.unsure;
    return _claude.ask(
      await file.readAsBytes(),
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
    );
  }

  Future<Uint8List?> _shrink(String path) async {
    try {
      final Uint8List? native = await _channel.invokeMethod<Uint8List>(
        'downscale',
        <String, Object?>{'path': path, 'maxEdge': _sendAt, 'quality': 0.7},
      );
      if (native != null && native.isNotEmpty) return native;
    } on Object catch (e) {
      debugPrint('Layla Pro: native mat downscale failed ($e)');
    }
    // No bridge, or it failed: shrink in Dart instead. Slower, but it means
    // the one copy that goes to Claude is always small enough to be sent —
    // a full capture is over the Worker's limit, and refusing to send it was
    // how Android quietly went without the second opinion.
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      return await compute(shrinkInDart, bytes);
    } on Object catch (e) {
      debugPrint('Layla Pro: mat downscale failed ($e)');
      return null;
    }
  }

  @visibleForTesting
  static Uint8List? shrinkInDart(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final img.Image upright = img.bakeOrientation(decoded);
    final int longest = upright.width > upright.height
        ? upright.width
        : upright.height;
    final img.Image small = longest > _sendAt
        ? img.copyResize(
            upright,
            width: upright.width >= upright.height ? _sendAt : null,
            height: upright.height > upright.width ? _sendAt : null,
            interpolation: img.Interpolation.average,
          )
        : upright;
    return Uint8List.fromList(img.encodeJpg(small, quality: 70));
  }

  /// The frame as a JPEG, upright, by the native side — the only side that
  /// knows the frame's real pixel format. Null when there is no bridge.
  Future<Uint8List?> frameJpeg(MatFrame frame) async {
    try {
      return await _channel.invokeMethod<Uint8List>(
        'frameToJpeg',
        _frameArgs(frame),
      );
    } on Object catch (e) {
      debugPrint('Layla Pro: frame could not be kept natively ($e)');
      return null;
    }
  }

  static Map<String, Object?> _frameArgs(MatFrame frame) => <String, Object?>{
    'bytes': frame.bytes,
    'y': frame.bytes,
    'width': frame.width,
    'height': frame.height,
    'bytesPerRow': frame.bytesPerRow,
    'yRowStride': frame.bytesPerRow,
    'orientation': frame.exifOrientation,
    'rotation': ((frame.sensorOrientation % 360) + 360) % 360,
    if (frame.u != null) 'u': frame.u,
    if (frame.v != null) 'v': frame.v,
    if (frame.uvRowStride != null) 'uvRowStride': frame.uvRowStride,
    if (frame.uvPixelStride != null) 'uvPixelStride': frame.uvPixelStride,
  };

  Future<List<VisionLabel>> _labels(String path) =>
      _ask('classify', <String, Object?>{'path': path});

  Future<List<VisionLabel>> _frameLabels(MatFrame frame) =>
      _ask('classifyFrame', _frameArgs(frame));

  Future<List<VisionLabel>> _ask(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final List<Object?>? raw = await _channel.invokeMethod<List<Object?>>(
        method,
        arguments,
      );
      if (raw == null) return <VisionLabel>[];

      return <VisionLabel>[
        for (final Object? e in raw)
          if (e is Map)
            VisionLabel(
              (e['label'] as String?) ?? '',
              ((e['confidence'] as num?) ?? 0).toDouble(),
            ),
      ];
    } on MissingPluginException {
      // Android, or a build without the bridge.
      return <VisionLabel>[];
    } on PlatformException catch (e) {
      debugPrint('Layla Pro: mat check unavailable (${e.code})');
      return <VisionLabel>[];
    } on Object catch (e) {
      debugPrint('Layla Pro: mat check failed ($e)');
      return <VisionLabel>[];
    }
  }
}
