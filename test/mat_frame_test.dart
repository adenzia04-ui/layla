import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/prayer_lock/data/mat_vision.dart';

/// The scanner's frames arrive in the sensor's own orientation, and this is
/// the only thing that turns them upright before the classifier sees them.
///
/// Worth a test because getting it wrong is silent. A frame rotated the wrong
/// way still classifies — it just classifies a sideways room, so the check
/// quietly gets worse at recognising mats and nothing anywhere says so.
MatFrame frameAt(int degrees) => MatFrame(
  bytes: Uint8List(0),
  width: 1280,
  height: 720,
  bytesPerRow: 5120,
  sensorOrientation: degrees,
);

void main() {
  test('an upright sensor needs no turn', () {
    expect(frameAt(0).exifOrientation, 1); // .up
  });

  test('a quarter turn clockwise is EXIF right', () {
    expect(frameAt(90).exifOrientation, 6); // .right — the iOS back camera
  });

  test('a half turn is EXIF down', () {
    expect(frameAt(180).exifOrientation, 3); // .down
  });

  test('three quarters is EXIF left', () {
    expect(frameAt(270).exifOrientation, 8); // .left
  });

  test('a full turn is upright again', () {
    expect(frameAt(360).exifOrientation, 1);
  });

  test('a negative rotation wraps rather than falling through to upright', () {
    // -90 is 270. Without the double modulo this landed on the default and
    // every frame from such a sensor would have been left lying on its side.
    expect(frameAt(-90).exifOrientation, 8);
  });

  test('an orientation nobody has is treated as upright, not as an error', () {
    // Better a frame that is merely unrotated than a scanner that throws
    // mid-prayer over a number it did not expect.
    expect(frameAt(45).exifOrientation, 1);
  });
}
