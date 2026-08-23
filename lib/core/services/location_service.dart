import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/result.dart';
import 'prefs_service.dart';

/// A resolved place: precise coordinates (kept on-device and in the user's own
/// private document) plus a human label for the header.
class NoorPlace {
  const NoorPlace({
    required this.lat,
    required this.lng,
    this.city = '',
    this.country = '',
    this.isStale = false,
  });

  final double lat;
  final double lng;
  final String city;
  final String country;

  /// True when this came from the cache rather than a live fix.
  final bool isStale;

  String get label {
    if (city.isEmpty && country.isEmpty) return 'Your location';
    if (city.isEmpty) return country;
    return country.isEmpty ? city : '$city, $country';
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'lat': lat,
        'lng': lng,
        'city': city,
        'country': country,
      };
}

final Provider<LocationService> locationServiceProvider =
    Provider<LocationService>(
  (Ref ref) => LocationService(ref.watch(prefsProvider)),
);

/// Resolves the device position, with a cached fallback so the dashboard can
/// always render something — prayer times must never show a blank screen.
class LocationService {
  const LocationService(this._prefs);

  final PrefsService _prefs;

  /// Cached position, if we ever had one. Synchronous — safe for first paint.
  NoorPlace? get cached {
    final cache = _prefs.cachedLocation;
    if (cache == null) return null;
    return NoorPlace(
      lat: cache.lat,
      lng: cache.lng,
      city: cache.city,
      country: cache.country,
      isStale: true,
    );
  }

  /// Requests a live fix. Throws [AppFailure] with an actionable message when
  /// services are off or permission is refused.
  Future<NoorPlace> current({bool reverseGeocode = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AppFailure(
        'Location services are turned off. Turn them on to get accurate '
        'prayer times and Qibla direction.',
        code: 'location-services-disabled',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const AppFailure(
        'Location permission is blocked. Enable it in Settings to get prayer '
        'times for where you are.',
        code: 'location-denied-forever',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const AppFailure(
        'Layla needs your location to calculate prayer times and Qibla.',
        code: 'location-denied',
      );
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );

    String city = '';
    String country = '';
    if (reverseGeocode) {
      final ({String city, String country}) named =
          await _describe(position.latitude, position.longitude);
      city = named.city;
      country = named.country;
    }

    await _prefs.cacheLocation(
      lat: position.latitude,
      lng: position.longitude,
      city: city,
      country: country,
    );

    return NoorPlace(
      lat: position.latitude,
      lng: position.longitude,
      city: city,
      country: country,
    );
  }

  /// Live fix if possible, cached otherwise — the dashboard's preferred path.
  Future<NoorPlace> currentOrCached() async {
    try {
      return await current();
    } on Object catch (error) {
      final NoorPlace? fallback = cached;
      if (fallback != null) return fallback;
      throw AppFailure.from(error);
    }
  }

  /// Reverse geocoding is best-effort; a missing city never blocks the app.
  Future<({String city, String country})> _describe(
    double lat,
    double lng,
  ) async {
    try {
      final List<Placemark> marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return (city: '', country: '');
      final Placemark m = marks.first;
      return (
        city: m.locality?.isNotEmpty ?? false
            ? m.locality!
            : (m.subAdministrativeArea ?? m.administrativeArea ?? ''),
        country: m.country ?? '',
      );
    } on Object {
      return (city: '', country: '');
    }
  }
}
