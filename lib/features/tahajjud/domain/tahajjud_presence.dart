import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// A believer currently praying Tahajjud, as seen by everyone else.
///
/// Note what is *not* here: no precise coordinates, no address, no email, no
/// photo. [lat]/[lng] are the centre of a ~5 km geohash cell nudged by a
/// stable per-user offset — enough to cluster a city, not enough to find a
/// home. See `core/utils/geohash.dart`.
@immutable
class TahajjudPresence {
  const TahajjudPresence({
    required this.uid,
    required this.displayName,
    required this.cellGeohash,
    required this.lat,
    required this.lng,
    required this.startedAt,
    required this.expiresAt,
    this.countryCode = '',
  });

  final String uid;

  /// "A believer" when the user chose to stay unnamed.
  final String displayName;
  final String cellGeohash;
  final double lat;
  final double lng;
  final DateTime startedAt;
  final DateTime expiresAt;
  final String countryCode;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get elapsed => DateTime.now().difference(startedAt);

  factory TahajjudPresence.fromDoc(
    DocumentSnapshot<Map<String, Object?>> doc,
  ) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    return TahajjudPresence(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'A believer',
      cellGeohash: data['cellGeohash'] as String? ?? '',
      lat: (data['cellLat'] as num?)?.toDouble() ?? 0,
      lng: (data['cellLng'] as num?)?.toDouble() ?? 0,
      startedAt:
          (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(minutes: 90)),
      countryCode: data['countryCode'] as String? ?? '',
    );
  }
}

/// Presences collapsed to one marker per geohash cell, so a busy city reads as
/// "12 praying here" instead of twelve overlapping pins.
@immutable
class PresenceCluster {
  const PresenceCluster({
    required this.geohash,
    required this.lat,
    required this.lng,
    required this.count,
    required this.includesMe,
  });

  final String geohash;
  final double lat;
  final double lng;
  final int count;
  final bool includesMe;

  static List<PresenceCluster> from(
    List<TahajjudPresence> people,
    String? myUid,
  ) {
    final Map<String, List<TahajjudPresence>> byCell =
        <String, List<TahajjudPresence>>{};
    for (final TahajjudPresence p in people) {
      byCell.putIfAbsent(p.cellGeohash, () => <TahajjudPresence>[]).add(p);
    }
    return byCell.entries.map((MapEntry<String, List<TahajjudPresence>> e) {
      final List<TahajjudPresence> group = e.value;
      return PresenceCluster(
        geohash: e.key,
        // Average within the cell keeps the marker inside its own area.
        lat: group.fold<double>(0, (double s, TahajjudPresence p) => s + p.lat) /
            group.length,
        lng: group.fold<double>(0, (double s, TahajjudPresence p) => s + p.lng) /
            group.length,
        count: group.length,
        includesMe:
            myUid != null && group.any((TahajjudPresence p) => p.uid == myUid),
      );
    }).toList(growable: false);
  }
}
