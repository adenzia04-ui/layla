import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../friends/application/friends_controller.dart';
import '../../friends/data/friends_repository.dart';
import '../../friends/domain/friend.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../data/circles_repository.dart';
import '../domain/circle.dart';

/// Every circle I am in, live. Empty, not loading, when there is no account
/// to be in one — circles hang off `friendsUidProvider` like the rest of
/// Friends, and a guest has none.
final StreamProvider<List<Circle>> circlesProvider =
    StreamProvider<List<Circle>>((Ref ref) {
      final String? uid = ref.watch(friendsUidProvider);
      if (uid == null) return Stream<List<Circle>>.value(const <Circle>[]);
      return ref.watch(circlesRepositoryProvider).watchMine(uid);
    });

/// One circle by id, live. Null once it cannot be read.
///
/// Auto-disposed: leaving a circle turns its listener into a permanent
/// permission error, and letting it go with the screen keeps neither the
/// listener nor the error around.
final AutoDisposeStreamProviderFamily<Circle?, String> circleProvider =
    StreamProvider.autoDispose.family<Circle?, String>(
      (Ref ref, String circleId) =>
          ref.watch(circlesRepositoryProvider).watchCircle(circleId),
    );

/// Every member's count for one circle, live. Listed beside the members and
/// summed into the shared bar; never sorted into an order.
final AutoDisposeStreamProviderFamily<List<CircleProgress>, String>
circleMembersProgressProvider = StreamProvider.autoDispose
    .family<List<CircleProgress>, String>(
      (Ref ref, String circleId) =>
          ref.watch(circlesRepositoryProvider).watchProgress(circleId),
    );

/// The circle with [circleId] from my list, or null.
Circle? _mine(List<Circle>? circles, String circleId) {
  for (final Circle circle in circles ?? const <Circle>[]) {
    if (circle.id == circleId) return circle;
  }
  return null;
}

/// My own recorded days inside one circle's span, live.
///
/// Selected down to the span so that a circle document changing in some
/// other way — a member joining — does not tear the listener down and open
/// it again. Empty, not loading, when the circle is not on my list.
final AutoDisposeStreamProviderFamily<List<PrayerDay>, String>
_circleDaysProvider = StreamProvider.autoDispose
    .family<List<PrayerDay>, String>((Ref ref, String circleId) {
      final String? uid = ref.watch(friendsUidProvider);
      final ({String from, String to})? span = ref.watch(
        circlesProvider.select((AsyncValue<List<Circle>> value) {
          final Circle? circle = _mine(value.valueOrNull, circleId);
          return circle == null
              ? null
              : (from: circle.startsOn, to: circle.endsOn);
        }),
      );
      if (uid == null || span == null) {
        return Stream<List<PrayerDay>>.value(const <PrayerDay>[]);
      }
      return ref
          .watch(circlesRepositoryProvider)
          .watchMyDays(uid: uid, from: span.from, to: span.to);
    });

/// How many days I have kept in one circle, computed on this phone from my
/// own day documents. Null while those are loading, or when the circle is
/// not one of mine.
///
/// This is the number the circle publishes for me, and the only thing it
/// ever learns about my days. Every day the pause covered simply adds
/// nothing to it — see `CircleGoal.keptOn`.
final AutoDisposeProviderFamily<int?, String> myCircleKeptProvider = Provider
    .autoDispose
    .family<int?, String>((Ref ref, String circleId) {
      final Circle? circle = ref.watch(
        circlesProvider.select(
          (AsyncValue<List<Circle>> value) =>
              _mine(value.valueOrNull, circleId),
        ),
      );
      if (circle == null) return null;
      final AsyncValue<List<PrayerDay>> days = ref.watch(
        _circleDaysProvider(circleId),
      );
      if (days.isLoading || days.hasError) return null;
      return circle.keptOn(
        days.valueOrNull ?? const <PrayerDay>[],
        ref.watch(todayProvider),
      );
    });

/// Publishes my count for every circle I am in, whenever it changes. Watched
/// once from the app shell, like the progress publisher.
///
/// Idempotent twice over. Against the server: nothing is written while the
/// circle already holds the number this phone computes, so a launch that
/// changes nothing writes nothing. Against itself: a value once sent is not
/// sent again this launch, so a write the rules refuse — after leaving the
/// circle, say — is not retried on every snapshot.
final Provider<void> circleSyncProvider = Provider<void>((Ref ref) {
  final String? uid = ref.watch(friendsUidProvider);
  if (uid == null) return;
  final List<Circle> circles =
      ref.watch(circlesProvider).valueOrNull ?? const <Circle>[];
  final _KeptPublisher publisher = ref.watch(_keptPublisherProvider);

  for (final Circle circle in circles) {
    final int? kept = ref.watch(myCircleKeptProvider(circle.id));
    if (kept == null) continue;
    final AsyncValue<List<CircleProgress>> progress = ref.watch(
      circleMembersProgressProvider(circle.id),
    );
    if (progress.isLoading || progress.hasError) continue;
    CircleProgress? stored;
    for (final CircleProgress p
        in progress.valueOrNull ?? const <CircleProgress>[]) {
      if (p.uid == uid) stored = p;
    }
    if (stored != null && stored.kept == kept) continue;
    publisher.publish(circleId: circle.id, kept: kept);
  }
});

final Provider<_KeptPublisher> _keptPublisherProvider =
    Provider<_KeptPublisher>(
      (Ref ref) => _KeptPublisher(ref.watch(circlesRepositoryProvider)),
    );

/// The memory of what was last sent per circle, kept out of the provider
/// above so that it survives every rebuild of it.
class _KeptPublisher {
  _KeptPublisher(this._repo);

  final CirclesRepository _repo;

  final Map<String, int> _sent = <String, int>{};

  void publish({required String circleId, required int kept}) {
    if (_sent[circleId] == kept) return;
    _sent[circleId] = kept;
    unawaited(
      _repo
          .publishKept(circleId: circleId, kept: kept)
          .catchError(
            (Object error) =>
                debugPrint('Layla Pro: circle progress not published ($error)'),
          ),
    );
  }
}

/// Creating, joining, leaving and inviting into circles, with the busy and
/// error state a screen needs.
///
/// `create` and `join` hand back the circle, or null when they failed — the
/// reason is then in `state.error`: a [CircleJoinException] for anything the
/// person can act on, otherwise whatever Firestore threw.
final NotifierProvider<CircleActions, AsyncValue<void>> circleActionsProvider =
    NotifierProvider<CircleActions, AsyncValue<void>>(CircleActions.new);

class CircleActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  CirclesRepository get _repo => ref.read(circlesRepositoryProvider);

  /// A circle starting today, with me in it.
  Future<Circle?> create(String name, CircleGoal goal) async {
    state = const AsyncValue<void>.loading();
    Circle? made;
    state = await AsyncValue.guard(() async {
      made = await _repo.create(
        name: name,
        goal: goal,
        now: ref.read(todayProvider),
      );
    });
    return state.hasError ? null : made;
  }

  /// Joins the circle behind [code].
  ///
  /// Hands back the circle once it can be read, which is only after the join
  /// has landed; a read that fails after a join that succeeded is still a
  /// join that succeeded, so it comes back as null with no error.
  Future<Circle?> join(String code) async {
    state = const AsyncValue<void>.loading();
    Circle? joined;
    state = await AsyncValue.guard(() async {
      // Checked against my own list first: the rules refuse a join that adds
      // nobody, and "already in it" is a better sentence than "refused".
      final String clean = FriendCode.normalize(code);
      for (final Circle circle
          in ref.read(circlesProvider).valueOrNull ?? const <Circle>[]) {
        if (circle.code == clean) {
          throw const CircleJoinException(CircleJoinError.already);
        }
      }
      final String circleId = await _repo.join(code);
      try {
        joined = await _repo.fetch(circleId);
      } on Object catch (error) {
        debugPrint('Layla Pro: joined circle not read back ($error)');
      }
    });
    return state.hasError ? null : joined;
  }

  Future<void> leave(String circleId) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() => _repo.leave(circleId));
  }

  /// Puts a circle invitation — the circle's id and code — in a friend's
  /// inbox. The code comes off my own list where it can, and off the circle
  /// document otherwise.
  Future<void> invite(String friendUid, String circleId) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final Circle? circle =
          _mine(ref.read(circlesProvider).valueOrNull, circleId) ??
          await _repo.fetch(circleId);
      if (circle == null) {
        throw const AppFailure(
          'That circle could not be found.',
          code: 'circle-not-found',
        );
      }
      await ref
          .read(friendsRepositoryProvider)
          .sendCircleInvite(
            friendUid: friendUid,
            fromName: FriendName.clean(
              ref.read(appUserProvider).valueOrNull?.displayName,
            ),
            circleId: circle.id,
            circleCode: circle.code,
          );
    });
  }
}
