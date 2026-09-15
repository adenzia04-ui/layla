import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  });

  /// A single BGRA plane, exactly as the preview stream delivers it.
  final Uint8List bytes;
  final int width;
  final int height;
  final int bytesPerRow;

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

/// Asks iOS to classify the Step 2 photo, on the device.
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
      return await _channel.invokeMethod<Uint8List>(
        'downscale',
        <String, Object?>{'path': path, 'maxEdge': _sendAt, 'quality': 0.7},
      );
    } on Object catch (e) {
      // Not fatal: the full capture still answers the question, it just costs
      // more. A platform with no bridge never reaches here anyway, because
      // there is no margin without one and so nothing to escalate.
      debugPrint('Layla Pro: mat downscale failed ($e)');
      return null;
    }
  }

  Future<List<VisionLabel>> _labels(String path) =>
      _ask('classify', <String, Object?>{'path': path});

  Future<List<VisionLabel>> _frameLabels(MatFrame frame) =>
      _ask('classifyFrame', <String, Object?>{
        'bytes': frame.bytes,
        'width': frame.width,
        'height': frame.height,
        'bytesPerRow': frame.bytesPerRow,
        'orientation': frame.exifOrientation,
      });

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
