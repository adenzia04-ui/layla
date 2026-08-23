import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';

/// How close to the Qibla counts as "facing it". A prayer direction does not
/// need to be exact — this is a generous, honest tolerance.
const double kQiblaToleranceDegrees = 5;

/// Raw compass heading in degrees from magnetic north, plus the sensor's own
/// confidence. Null heading means the device has no magnetometer.
@immutable
class CompassReading {
  const CompassReading({this.heading, this.accuracy});

  final double? heading;

  /// Radians of expected error, as reported by the platform. Higher is worse.
  final double? accuracy;

  bool get hasSensor => heading != null;

  /// Android reports accuracy in radians; anything above ~0.26 rad (15°) means
  /// the user should do the figure-eight calibration.
  bool get needsCalibration => (accuracy ?? 0) > 0.26;
}

final StreamProvider<CompassReading> compassProvider =
    StreamProvider<CompassReading>((Ref ref) {
  final Stream<CompassEvent>? events = FlutterCompass.events;
  if (events == null) {
    return Stream<CompassReading>.value(const CompassReading());
  }
  return events.map(
    (CompassEvent event) => CompassReading(
      heading: event.heading,
      accuracy: event.accuracy,
    ),
  );
});

/// Everything the Qibla screen needs, resolved together.
@immutable
class QiblaState {
  const QiblaState({
    required this.qiblaBearing,
    required this.heading,
    required this.hasSensor,
    required this.needsCalibration,
    required this.distanceKm,
  });

  /// Degrees clockwise from north to the Kaaba, from the user's position.
  final double qiblaBearing;

  /// Current device heading. Null when there is no compass.
  final double? heading;
  final bool hasSensor;
  final bool needsCalibration;
  final double distanceKm;

  /// How far the phone must still turn: the angle to rotate the needle by.
  double get relativeAngle =>
      heading == null ? qiblaBearing : (qiblaBearing - heading!);

  /// Absolute error in degrees, normalised to 0–180.
  double get offBy {
    if (heading == null) return 180;
    final double diff = (qiblaBearing - heading!).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }

  bool get isAligned => hasSensor && offBy <= kQiblaToleranceDegrees;

  /// "NNE", "SW" — a plain-language fallback when the compass is unavailable.
  String get compassPoint {
    const List<String> points = <String>[
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW',
    ];
    return points[(((qiblaBearing % 360) / 22.5) + 0.5).floor() % 16];
  }
}

final Provider<AsyncValue<QiblaState>> qiblaProvider =
    Provider<AsyncValue<QiblaState>>((Ref ref) {
  final AsyncValue<PrayerSchedule> schedule = ref.watch(prayerScheduleProvider);
  final CompassReading compass =
      ref.watch(compassProvider).value ?? const CompassReading();

  return schedule.whenData(
    (PrayerSchedule s) => QiblaState(
      qiblaBearing: s.qiblaBearing,
      heading: compass.heading,
      hasSensor: compass.hasSensor,
      needsCalibration: compass.needsCalibration,
      distanceKm: _kaabaDistanceKm(s.latitude, s.longitude),
    ),
  );
});

/// Great-circle distance to the Kaaba, shown under the compass.
double _kaabaDistanceKm(double lat, double lng) {
  const double kaabaLat = 21.4224779;
  const double kaabaLng = 39.8251832;
  const double radius = 6371.0;
  double rad(double d) => d * math.pi / 180;

  final double dLat = rad(kaabaLat - lat);
  final double dLng = rad(kaabaLng - lng);
  final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat)) *
          math.cos(rad(kaabaLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
