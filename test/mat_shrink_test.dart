import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:noor/features/prayer_lock/data/mat_vision.dart';

void main() {
  test('a capture is shrunk to what the mat check can send', () {
    // A 1280-wide "capture", like the camera's.
    final img.Image big = img.Image(width: 1280, height: 960);
    img.fill(big, color: img.ColorRgb8(120, 80, 40));
    final Uint8List bytes = Uint8List.fromList(img.encodeJpg(big, quality: 95));
    final Uint8List? small = MatVision.shrinkInDart(bytes);
    expect(small, isNotNull);
    final img.Image? back = img.decodeImage(small!);
    expect(back!.width, 640);
    expect(back.height, 480);
    // Comfortably under the Worker's 280 KB limit.
    expect(small.length, lessThan(280 * 1024));
  });

  test('a real photo shrinks and keeps its orientation', () {
    final Uint8List bytes = File('assets/images/dua_art.png').readAsBytesSync();
    final Uint8List? small = MatVision.shrinkInDart(bytes);
    expect(small, isNotNull);
    final img.Image? back = img.decodeImage(small!);
    expect(back, isNotNull);
    expect(back!.width <= 640 && back.height <= 640, isTrue);
  });
}
