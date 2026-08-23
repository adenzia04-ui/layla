import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/dhikr.dart';

@immutable
class TasbihState {
  const TasbihState({
    required this.count,
    required this.target,
    required this.dhikr,
    this.setsCompleted = 0,
  });

  final int count;
  final int target;
  final Dhikr dhikr;

  /// How many times the target has been reached in this sitting.
  final int setsCompleted;

  double get progress => target == 0 ? 0 : (count / target).clamp(0, 1);
  bool get isComplete => count >= target;
  int get remaining => (target - count).clamp(0, target);

  TasbihState copyWith({
    int? count,
    int? target,
    Dhikr? dhikr,
    int? setsCompleted,
  }) =>
      TasbihState(
        count: count ?? this.count,
        target: target ?? this.target,
        dhikr: dhikr ?? this.dhikr,
        setsCompleted: setsCompleted ?? this.setsCompleted,
      );
}

final NotifierProvider<TasbihController, TasbihState> tasbihProvider =
    NotifierProvider<TasbihController, TasbihState>(TasbihController.new);

/// Counting must feel instant, so the count lives in memory and is mirrored to
/// SharedPreferences. Firestore only ever sees a finished set.
class TasbihController extends Notifier<TasbihState> {
  @override
  TasbihState build() {
    final PrefsService prefs = ref.watch(prefsProvider);
    return TasbihState(
      count: prefs.tasbihCount,
      target: prefs.tasbihTarget,
      dhikr: Dhikr.byName(prefs.tasbihDhikr),
    );
  }

  PrefsService get _prefs => ref.read(prefsProvider);

  void increment() {
    final int next = state.count + 1;
    final bool justCompleted = next == state.target;

    if (justCompleted) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    state = state.copyWith(
      count: next,
      setsCompleted:
          justCompleted ? state.setsCompleted + 1 : state.setsCompleted,
    );
    _prefs.setTasbihCount(next);

    if (justCompleted) _recordSet();
  }

  void reset() {
    HapticFeedback.mediumImpact();
    state = state.copyWith(count: 0);
    _prefs.setTasbihCount(0);
  }

  void setTarget(int target) {
    final int clamped = target.clamp(1, 10000);
    state = state.copyWith(target: clamped);
    _prefs.setTasbihTarget(clamped);
  }

  /// Switching dhikr starts a fresh count and adopts that dhikr's usual target.
  void setDhikr(Dhikr dhikr) {
    state = state.copyWith(
      dhikr: dhikr,
      target: dhikr.defaultTarget,
      count: 0,
    );
    _prefs
      ..setTasbihDhikr(dhikr.name)
      ..setTasbihTarget(dhikr.defaultTarget)
      ..setTasbihCount(0);
  }

  /// A completed set is written to `users/{uid}/tasbih_sessions` for history.
  /// Failure here is silent by design — losing a log entry must never
  /// interrupt someone's dhikr.
  Future<void> _recordSet() async {
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final String? uid = auth.uid;
    if (uid == null) return;
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('tasbih_sessions')
          .add(<String, Object?>{
        'dhikr': state.dhikr.name,
        'target': state.target,
        'count': state.target,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } on Object catch (error) {
      debugPrint('Layla: tasbih set not saved ($error)');
    }
  }
}
