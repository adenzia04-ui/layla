import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/geohash.dart';

void main() {
  // These tests exist to protect a privacy promise, not just an algorithm:
  // nothing published to the Tahajjud map may be precise enough to locate a
  // person's home.
  group('Geo.encode', () {
    test('matches known geohashes', () {
      expect(Geo.encode(21.4225, 39.8262), 'sgu3f'); // the Kaaba
      expect(Geo.encode(51.5074, -0.1278), 'gcpvj'); // London
    });

    test('always returns the requested precision', () {
      expect(Geo.encode(3.139, 101.6869).length, Geo.mapPrecision);
      expect(Geo.encode(3.139, 101.6869, precision: 7).length, 7);
    });
  });

  group('Geo.coarsePoint', () {
    const double lat = 3.139;
    const double lng = 101.6869;

    test('stays inside its own cell', () {
      final cell = Geo.decode(Geo.encode(lat, lng));
      final point = Geo.coarsePoint(lat, lng, 'user-abc');

      expect((point.lat - cell.lat).abs(), lessThanOrEqualTo(cell.latErr));
      expect((point.lng - cell.lng).abs(), lessThanOrEqualTo(cell.lngErr));
    });

    test('is deterministic — a user does not appear to wander', () {
      final a = Geo.coarsePoint(lat, lng, 'user-abc');
      final b = Geo.coarsePoint(lat, lng, 'user-abc');
      expect(a.lat, b.lat);
      expect(a.lng, b.lng);
    });

    test('separates two users in the same cell', () {
      final a = Geo.coarsePoint(lat, lng, 'user-abc');
      final b = Geo.coarsePoint(lat, lng, 'user-xyz');
      expect(a.lat == b.lat && a.lng == b.lng, isFalse);
    });

    test('discards precision: two nearby people share one cell', () {
      // ~570 m apart — far enough to identify a street, and the whole point is
      // that the map cannot tell them apart.
      expect(Geo.encode(3.1400, 101.6700), Geo.encode(3.1436, 101.6736));
    });

    test('published point is at least a few hundred metres off the truth', () {
      final point = Geo.coarsePoint(lat, lng, 'user-abc');
      final double error = Geo.distanceKm(lat, lng, point.lat, point.lng);
      expect(error, greaterThan(0.05));
      expect(error, lessThan(6)); // still inside the ~5 km cell
    });
  });

  group('Geo.distanceKm', () {
    test('computes a known distance', () {
      // London to Makkah is about 4,780 km.
      final double d = Geo.distanceKm(51.5074, -0.1278, 21.4225, 39.8262);
      expect(d, closeTo(4780, 60));
    });
  });
}
