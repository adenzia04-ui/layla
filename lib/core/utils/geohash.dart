import 'dart:math' as math;

/// Privacy-safe location handling for the Tahajjud live map.
///
/// Noor never stores or transmits a user's precise coordinates for the map.
/// A position is reduced to a **geohash cell** and then reported as that
/// cell's centre plus a small deterministic offset, so two people in the same
/// neighbourhood do not stack on one pixel while nobody's home is revealed.
abstract final class Geo {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
  static const List<int> _bits = <int>[16, 8, 4, 2, 1];

  /// Precision 5 ≈ a 4.9 km × 4.9 km cell. This is the map's resolution and
  /// the only spatial data written to `tahajjud_presence`.
  static const int mapPrecision = 5;

  static String encode(double lat, double lng, {int precision = mapPrecision}) {
    final List<double> latRange = <double>[-90, 90];
    final List<double> lngRange = <double>[-180, 180];
    final StringBuffer out = StringBuffer();
    bool even = true;
    int bit = 0;
    int ch = 0;

    while (out.length < precision) {
      if (even) {
        final double mid = (lngRange[0] + lngRange[1]) / 2;
        if (lng > mid) {
          ch |= _bits[bit];
          lngRange[0] = mid;
        } else {
          lngRange[1] = mid;
        }
      } else {
        final double mid = (latRange[0] + latRange[1]) / 2;
        if (lat > mid) {
          ch |= _bits[bit];
          latRange[0] = mid;
        } else {
          latRange[1] = mid;
        }
      }
      even = !even;
      if (bit < 4) {
        bit++;
      } else {
        out.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return out.toString();
  }

  /// Returns the centre of a geohash cell.
  static ({double lat, double lng, double latErr, double lngErr}) decode(
    String hash,
  ) {
    final List<double> latRange = <double>[-90, 90];
    final List<double> lngRange = <double>[-180, 180];
    bool even = true;

    for (final String c in hash.split('')) {
      final int idx = _base32.indexOf(c);
      if (idx < 0) continue;
      for (final int mask in _bits) {
        final List<double> range = even ? lngRange : latRange;
        final double mid = (range[0] + range[1]) / 2;
        if (idx & mask != 0) {
          range[0] = mid;
        } else {
          range[1] = mid;
        }
        even = !even;
      }
    }
    return (
      lat: (latRange[0] + latRange[1]) / 2,
      lng: (lngRange[0] + lngRange[1]) / 2,
      latErr: (latRange[1] - latRange[0]) / 2,
      lngErr: (lngRange[1] - lngRange[0]) / 2,
    );
  }

  /// The coarse point Noor publishes: the cell centre nudged by a stable,
  /// per-user offset that stays inside the cell. Deterministic, so a user does
  /// not appear to wander between sessions.
  static ({double lat, double lng}) coarsePoint(
    double lat,
    double lng,
    String seed,
  ) {
    final String hash = encode(lat, lng);
    final cell = decode(hash);
    final int h = _stableHash(seed);
    // two independent fractions in [-0.6, 0.6] of the cell half-size
    final double fx = ((h & 0xFFFF) / 0xFFFF - 0.5) * 1.2;
    final double fy = (((h >> 16) & 0xFFFF) / 0xFFFF - 0.5) * 1.2;
    return (lat: cell.lat + cell.latErr * fy, lng: cell.lng + cell.lngErr * fx);
  }

  /// FNV-1a — small, stable across runs and platforms.
  static int _stableHash(String input) {
    int hash = 0x811C9DC5;
    for (final int code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// Great-circle distance in kilometres — used to sort nearby believers.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371.0;
    final double dLat = _rad(lat2 - lat1);
    final double dLng = _rad(lng2 - lng1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
