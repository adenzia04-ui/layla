import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/widgets/domain/widget_theme.dart';

/// The nine colour sets exist three times over: in Dart, so the picker can
/// draw them; in Swift, so the iPhone widgets can; and in Kotlin plus a pile
/// of drawables, so the Android ones can.
///
/// Three copies of the same table is a drift waiting to happen, and the way
/// it would show up is somebody tapping Emerald and getting Midnight on one
/// of their two phones with nothing in any log. These pin the copies to each
/// other by name.
void main() {
  final List<String> ids = WidgetTheme.values
      .map((WidgetTheme t) => t.id)
      .toList();

  group('Widget colour sets', () {
    test('Dart still has the nine the other two were generated from', () {
      expect(ids, hasLength(9));
      expect(ids, contains('midnight'));
    });

    test('every set exists in the iOS palette table', () {
      final String swift = File(
        'ios/NoorWidgets/NoorTheme.swift',
      ).readAsStringSync();
      for (final String id in ids) {
        // Midnight is the `static let`; the rest are `case` arms.
        final bool present =
            swift.contains('case "$id":') || swift.contains('static let $id =');
        expect(present, isTrue, reason: '$id is missing from NoorTheme.swift');
      }
    });

    test('every set exists in the Android palette table', () {
      final String kotlin = File(
        'android/app/src/main/kotlin/com/adenzia/layla/WidgetPalette.kt',
      ).readAsStringSync();
      for (final String id in ids) {
        expect(
          kotlin.contains('"$id" to Palette('),
          isTrue,
          reason: '$id is missing from WidgetPalette.kt, so an Android widget '
              'in that set would quietly fall back to Midnight',
        );
      }
    });

    test('every set\'s ink is readable on its own ground', () {
      // Sand is the one set that inverts: a bone ground with dark brown ink.
      // The Android painter used to take its secondary text from the set's
      // hairline colour, which on the eight dark sets merely looked dim and
      // on Sand was pale beige on bone — the countdown, the prayer names,
      // the city and the footer were all there and all invisible. Nothing in
      // a build catches that, and nobody notices until a widget is on a home
      // screen. This does.
      final String kotlin = File(
        'android/app/src/main/kotlin/com/adenzia/layla/WidgetPalette.kt',
      ).readAsStringSync();

      for (final String id in ids) {
        final int ink = _cream(kotlin, id);
        for (final String ground in <String>['widget_bg', 'widget_cell']) {
          final int paper = _solid('${ground}_$id');
          expect(
            _contrast(ink, paper),
            greaterThanOrEqualTo(4.5),
            reason: '$id: body text ${_hex(ink)} on ${_hex(paper)} '
                '($ground) is not readable',
          );
          // The quiet text — names, city, footer — is the same ink at 70%.
          expect(
            _contrast(_over(ink, 0.7, paper), paper),
            greaterThanOrEqualTo(3.0),
            reason: '$id: secondary text on ${_hex(paper)} is not readable',
          );
        }
      }
    });

    test('every set has its three Android drawables', () {
      const String dir = 'android/app/src/main/res/drawable';
      for (final String id in ids) {
        for (final String role in <String>[
          'widget_bg',
          'widget_cell',
          'widget_cell_next',
        ]) {
          final File file = File('$dir/${role}_$id.xml');
          expect(
            file.existsSync(),
            isTrue,
            reason: '${file.path} is missing; the Android build would not '
                'compile with it referenced, or would draw the wrong set',
          );
        }
      }
    });
  });
}

/// The set's body-text colour, as `WidgetPalette.kt` stores it.
int _cream(String kotlin, String id) {
  final RegExp entry = RegExp(
    '"$id" to Palette\\((.*?)\\n        \\)',
    dotAll: true,
  );
  final RegExpMatch? block = entry.firstMatch(kotlin);
  expect(block, isNotNull, reason: '$id has no Palette entry');
  final RegExpMatch? cream =
      RegExp(r'cream = 0x([0-9A-Fa-f]{8})').firstMatch(block!.group(1)!);
  expect(cream, isNotNull, reason: '$id has no cream');
  return int.parse(cream!.group(1)!, radix: 16);
}

/// The single fill colour out of one of the generated shape drawables.
int _solid(String name) {
  final String xml = File(
    'android/app/src/main/res/drawable/$name.xml',
  ).readAsStringSync();
  final RegExpMatch? fill =
      RegExp(r'<solid android:color="#([0-9A-Fa-f]{8})"').firstMatch(xml);
  expect(fill, isNotNull, reason: '$name has no solid fill');
  return int.parse(fill!.group(1)!, radix: 16);
}

/// `foreground` at `alpha`, flattened onto `background`, the way the phone
/// composites a text colour that carries an alpha channel.
int _over(int foreground, double alpha, int background) {
  int mix(int shift) {
    final int f = (foreground >> shift) & 0xFF;
    final int b = (background >> shift) & 0xFF;
    return (f * alpha + b * (1 - alpha)).round();
  }

  return 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// WCAG relative luminance.
double _luminance(int argb) {
  double channel(int shift) {
    final double c = ((argb >> shift) & 0xFF) / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

double _contrast(int a, int b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
