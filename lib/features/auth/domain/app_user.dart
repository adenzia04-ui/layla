import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../prayer_times/domain/prayer_settings.dart';

/// Streak and prayer counters. The client updates these optimistically; the
/// `recalculateStreak` Cloud Function is the authority.
@immutable
class UserStats {
  const UserStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPrayers = 0,
    this.totalTahajjud = 0,
    this.lastCompletedDate,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalPrayers;
  final int totalTahajjud;

  /// "2026-08-20" — the last day all five prayers were confirmed.
  final String? lastCompletedDate;

  factory UserStats.fromMap(Map<String, Object?>? map) {
    if (map == null) return const UserStats();
    return UserStats(
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      totalPrayers: (map['totalPrayers'] as num?)?.toInt() ?? 0,
      totalTahajjud: (map['totalTahajjud'] as num?)?.toInt() ?? 0,
      lastCompletedDate: map['lastCompletedDate'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalPrayers': totalPrayers,
        'totalTahajjud': totalTahajjud,
        'lastCompletedDate': lastCompletedDate,
      };
}

@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isAnonymous = false,
    this.settings = const PrayerSettings(),
    this.stats = const UserStats(),
    this.city = '',
    this.country = '',
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAnonymous;
  final PrayerSettings settings;
  final UserStats stats;
  final String city;
  final String country;
  final DateTime? createdAt;

  /// "Assalamu alaikum, Aden" — first word only, so long names don't wrap.
  String get firstName =>
      displayName.trim().isEmpty ? 'friend' : displayName.trim().split(' ').first;

  /// One or two letters for the avatar circle.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Map<String, Object?> location =
        (data['location'] as Map<String, Object?>?) ?? <String, Object?>{};
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      settings:
          PrayerSettings.fromMap(data['settings'] as Map<String, Object?>?),
      stats: UserStats.fromMap(data['stats'] as Map<String, Object?>?),
      city: location['city'] as String? ?? '',
      country: location['country'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    PrayerSettings? settings,
    UserStats? stats,
    String? city,
    String? country,
  }) =>
      AppUser(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        photoUrl: photoUrl ?? this.photoUrl,
        isAnonymous: isAnonymous,
        settings: settings ?? this.settings,
        stats: stats ?? this.stats,
        city: city ?? this.city,
        country: country ?? this.country,
        createdAt: createdAt,
      );
}
