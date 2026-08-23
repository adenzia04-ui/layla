import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

final Provider<PrayerSettingsRepository> prayerSettingsRepositoryProvider =
    Provider<PrayerSettingsRepository>(
  (Ref ref) => PrayerSettingsRepository(ref.watch(authRepositoryProvider)),
);

/// Every settings mutation funnels through here so the whole map is written
/// back atomically and the UI updates from the Firestore stream.
class PrayerSettingsRepository {
  const PrayerSettingsRepository(this._auth);

  final AuthRepository _auth;

  Future<void> save(PrayerSettings settings) => _auth.updateSettings(settings);

  Future<void> setMethod(PrayerSettings current, CalcMethod method) =>
      save(current.copyWith(method: method));

  Future<void> setMadhab(PrayerSettings current, MadhabOption madhab) =>
      save(current.copyWith(madhab: madhab));

  Future<void> setAdjustment(
    PrayerSettings current,
    PrayerId prayer,
    int minutes,
  ) =>
      save(
        current.copyWith(
          adjustments: <String, int>{
            ...current.adjustments,
            prayer.key: minutes.clamp(-30, 30),
          },
        ),
      );

  Future<void> setNotification(
    PrayerSettings current,
    PrayerId prayer, {
    required bool enabled,
  }) =>
      save(
        current.copyWith(
          notifications: <String, bool>{
            ...current.notifications,
            prayer.key: enabled,
          },
        ),
      );

  Future<void> setLockEnabled(PrayerSettings current, {required bool enabled}) =>
      save(current.copyWith(lockEnabled: enabled));

  Future<void> setTahajjudVisible(
    PrayerSettings current, {
    required bool visible,
  }) =>
      save(current.copyWith(tahajjudVisible: visible));

  Future<void> setUse24hClock(PrayerSettings current, {required bool use24h}) =>
      save(current.copyWith(use24hClock: use24h));

  Future<void> setBlockScope(PrayerSettings current, BlockScope scope) =>
      save(current.copyWith(blockScope: scope));

  /// Turns app blocking on or off for a single prayer.
  ///
  /// Refuses to switch the last one off: a blocking feature that blocks
  /// nothing is a setting pretending to be a feature. Use the master toggle.
  Future<void> setBlocking(
    PrayerSettings current,
    PrayerId prayer, {
    required bool enabled,
  }) {
    if (!enabled && current.blockingCount <= 1 && current.blocks(prayer)) {
      return Future<void>.value();
    }
    return save(
      current.copyWith(
        blocking: <String, bool>{...current.blocking, prayer.key: enabled},
      ),
    );
  }
}
