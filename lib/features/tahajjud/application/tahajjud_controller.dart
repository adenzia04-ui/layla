import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../auth/data/auth_repository.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../streaks/data/prayer_day_repository.dart';
import '../data/tahajjud_repository.dart';
import '../domain/tahajjud_presence.dart';

/// Everyone praying right now.
final StreamProvider<List<TahajjudPresence>> tahajjudPresenceProvider =
    StreamProvider<List<TahajjudPresence>>(
      (Ref ref) => ref.watch(tahajjudRepositoryProvider).watchActive(),
    );

/// Just the number — cheap enough to show on the dashboard.
final Provider<AsyncValue<int>> tahajjudLiveCountProvider =
    Provider<AsyncValue<int>>(
      (Ref ref) => ref
          .watch(tahajjudPresenceProvider)
          .whenData((List<TahajjudPresence> list) => list.length),
    );

/// The current user's own presence, or null when they are not on the map.
final StreamProvider<TahajjudPresence?> mySessionProvider =
    StreamProvider<TahajjudPresence?>(
      (Ref ref) => ref.watch(tahajjudRepositoryProvider).watchMySession(),
    );

/// Presences grouped by geohash cell, ready for the map layer.
final Provider<AsyncValue<List<PresenceCluster>>> presenceClustersProvider =
    Provider<AsyncValue<List<PresenceCluster>>>((Ref ref) {
      final String? uid = ref.watch(authRepositoryProvider).uid;
      return ref
          .watch(tahajjudPresenceProvider)
          .whenData(
            (List<TahajjudPresence> people) =>
                PresenceCluster.from(people, uid),
          );
    });

final AutoDisposeAsyncNotifierProvider<TahajjudController, void>
tahajjudControllerProvider =
    AsyncNotifierProvider.autoDispose<TahajjudController, void>(
      TahajjudController.new,
    );

class TahajjudController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// "I am Praying Tahajjud" — records the night in the user's own history and,
  /// only if they have opted in to visibility, publishes a coarse presence.
  ///
  /// The two are deliberately separate: someone can log Tahajjud without ever
  /// appearing on the map.
  Future<bool> startPraying({
    required bool appearOnMap,
    bool anonymous = false,
  }) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(prayerDayRepositoryProvider).markTahajjud();

      if (!appearOnMap) return;

      // currentOrCached throws an AppFailure with an actionable message when
      // there is no fix and nothing cached, so there is nothing to null-check.
      final NoorPlace place =
          ref.read(placeProvider).valueOrNull ??
          await ref.read(locationServiceProvider).currentOrCached();
      final String name =
          ref.read(appUserProvider).valueOrNull?.displayName ?? 'A believer';
      await ref
          .read(tahajjudRepositoryProvider)
          .startSession(place: place, displayName: name, anonymous: anonymous);
    });
    return !state.hasError;
  }

  /// Leaves the map. The night still counts in the user's own history.
  Future<bool> stopAppearing() async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => ref.read(tahajjudRepositoryProvider).endSession(),
    );
    return !state.hasError;
  }
}
