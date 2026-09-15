import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One iPhone, in logical points — the unit Flutter lays out in.
///
/// Density is deliberately not a variable here. A 62pt button is 62pt on a 2x
/// iPhone 11 and on a 3x 17 Pro Max; the Pro Max simply draws it with more
/// pixels. Layout breaks come from points, so points are what we vary.
class Device {
  const Device(this.name, this.size, this.pixelRatio, this.padding);

  final String name;
  final Size size;
  final double pixelRatio;

  /// Notch/Dynamic Island at the top, home indicator at the bottom.
  final EdgeInsets padding;

  @override
  String toString() => '$name (${size.width.toInt()}x${size.height.toInt()})';
}

/// Every iPhone size Layla Pro can land on, narrowest and shortest first.
///
/// The SE is the one that matters. It is 65pt narrower and 289pt shorter than
/// the phone this app is developed on — if anything clips, it clips here first,
/// and in a release build it clips *silently*: the yellow overflow stripes are
/// painted only in debug, so a user on a small phone sees a shaved-off button
/// and never thinks to mention it.
const List<Device> kDevices = <Device>[
  Device('iPhone SE', Size(375, 667), 2, EdgeInsets.zero),
  Device(
    'iPhone 13 mini',
    Size(375, 812),
    3,
    EdgeInsets.only(top: 50, bottom: 34),
  ),
  Device('iPhone 14', Size(390, 844), 3, EdgeInsets.only(top: 47, bottom: 34)),
  Device('iPhone 17', Size(393, 852), 3, EdgeInsets.only(top: 59, bottom: 34)),
  Device('iPhone 11', Size(414, 896), 2, EdgeInsets.only(top: 48, bottom: 34)),
  Device(
    'iPhone 17 Pro Max',
    Size(440, 956),
    3,
    EdgeInsets.only(top: 62, bottom: 34),
  ),
];

/// The two ends of the Dynamic Type clamp set in `app.dart`.
///
/// Worth testing both: a user at 1.3x stresses a layout harder than any screen
/// size does, and the two compound — an SE at 1.3x is the true worst case.
const List<double> kTextScales = <double>[1.0, 1.3];

/// Applies [device] to the test view for the duration of one test.
void useDevice(WidgetTester tester, Device device) {
  tester.view.physicalSize = device.size * device.pixelRatio;
  tester.view.devicePixelRatio = device.pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Wraps [child] the way the running app does: real safe-area insets and a
/// clamped text scaler.
Widget asDevice({
  required Device device,
  required double textScale,
  required Widget child,
}) => MediaQuery(
  data: MediaQueryData(
    size: device.size,
    devicePixelRatio: device.pixelRatio,
    padding: device.padding,
    viewPadding: device.padding,
    textScaler: TextScaler.linear(textScale),
  ),
  child: child,
);
