import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/dhikr.dart';
import '../domain/sunnah_routine.dart';

/// Manual counts one dhikr against a target of your choosing. Sunnah walks the
/// after-prayer sequence — 33, 33, 34 — advancing on its own at each stage.
enum TasbihMode { manual, sunnah }

@immutable
class TasbihState {
  const TasbihState({
    required this.count,
    required this.target,
    required this.dhikr,
    this.mode = TasbihMode.manual,
    this.routine = SunnahRoutine.afterPrayer,
    this.stage = 0,
    this.setsCompleted = 0,
    this.roundsCompleted = 0,
    this.hurried = false,
  });

  final int count;
  final int target;
  final Dhikr dhikr;
  final TasbihMode mode;

  /// Which sunnah is being counted. Meaningless outside Sunnah mode.
  final SunnahRoutine routine;

  /// Position in [SunnahRoutine.stages]. Meaningless outside Sunnah mode.
  final int stage;

  /// Full rounds of the after-prayer sequence finished in this sitting. The
  /// screen watches this for changes rather than for a "complete" flag: a flag
  /// would have to be cleared afterwards, and whatever cleared it would decide
  /// whether the message ever appeared.
  final int roundsCompleted;

  /// How many times the target has been reached in this sitting.
  final int setsCompleted;

  /// True for a few seconds after the taps came too fast to be dhikr. The
  /// screen shows a word about slowing down while it is up.
  final bool hurried;

  double get progress => target == 0 ? 0 : (count / target).clamp(0, 1);
  bool get isComplete => count >= target;
  int get remaining => (target - count).clamp(0, target);

  bool get isSunnah => mode == TasbihMode.sunnah;

  /// Position through the whole hundred, for the ring in Sunnah mode. Stages
  /// already behind us count in full.
  int get sunnahDone {
    int done = count;
    for (int i = 0; i < stage; i++) {
      done += routine.stages[i].defaultTarget;
    }
    return done;
  }

  TasbihState copyWith({
    int? count,
    int? target,
    Dhikr? dhikr,
    TasbihMode? mode,
    SunnahRoutine? routine,
    int? stage,
    int? setsCompleted,
    int? roundsCompleted,
    bool? hurried,
  }) => TasbihState(
    count: count ?? this.count,
    target: target ?? this.target,
    dhikr: dhikr ?? this.dhikr,
    mode: mode ?? this.mode,
    routine: routine ?? this.routine,
    stage: stage ?? this.stage,
    setsCompleted: setsCompleted ?? this.setsCompleted,
    roundsCompleted: roundsCompleted ?? this.roundsCompleted,
    hurried: hurried ?? this.hurried,
  );
}

/// Whether the counter paces the taps. On for people; off in tests, whose
/// loops tap faster than any thumb.
final Provider<bool> tasbihPaceProvider = Provider<bool>((Ref ref) => true);

final NotifierProvider<TasbihController, TasbihState> tasbihProvider =
    NotifierProvider<TasbihController, TasbihState>(TasbihController.new);

/// Counting must feel instant, so the count lives in memory and is mirrored to
/// SharedPreferences. Firestore only ever sees a finished set.
class TasbihController extends Notifier<TasbihState> {
  @override
  TasbihState build() {
    final PrefsService prefs = ref.watch(prefsProvider);
    final TasbihMode mode = TasbihMode.values.firstWhere(
      (TasbihMode m) => m.name == prefs.tasbihMode,
      orElse: () => TasbihMode.manual,
    );
    final SunnahRoutine routine = SunnahRoutine.byId(prefs.tasbihRoutine);
    final int stage = prefs.tasbihStage.clamp(0, routine.stages.length - 1);
    return TasbihState(
      count: prefs.tasbihCount,
      // In Sunnah mode the stage owns the target; a stale saved target would
      // otherwise let a restart resume 33 SubhanAllah against a target of 100.
      target: mode == TasbihMode.sunnah
          ? routine.stages[stage].defaultTarget
          : prefs.tasbihTarget,
      dhikr: mode == TasbihMode.sunnah
          ? routine.stages[stage]
          : Dhikr.byName(prefs.tasbihDhikr),
      mode: mode,
      routine: routine,
      stage: stage,
    );
  }

  PrefsService get _prefs => ref.read(prefsProvider);

  // ── Pace ──────────────────────────────────────────────────────────────
  //
  // Dhikr is said, not tapped. A count that races ahead of the tongue is a
  // number, and the number was never the point. So two things: a tap that
  // lands within a quarter-second of the last is not counted at all, and a
  // run of taps faster than a person can say SubhanAllah raises a word on
  // screen for a few seconds. Neither is a punishment; the count simply
  // will not go faster than the words.

  /// The shortest gap between two counted taps.
  static const Duration _minGap = Duration(milliseconds: 280);

  /// Six taps inside this, and the person is hurrying.
  static const Duration _hurryWindow = Duration(milliseconds: 2200);
  static const int _hurryTaps = 6;

  /// How long the hurrying has to go on before the veil comes over the screen.
  /// A burst of quick taps is not a pattern; two seconds of it is.
  static const Duration _hurryFor = Duration(seconds: 2);

  final List<DateTime> _taps = <DateTime>[];
  DateTime? _hurryStart;
  Timer? _calm;

  /// Every tap counts until the veil is up. This watches the pace, raises the
  /// veil once the hurrying has gone on long enough, and holds the count
  /// still while it shows.
  bool _pace() {
    if (!ref.read(tasbihPaceProvider)) return true;
    final DateTime now = DateTime.now();
    final bool tooSoon =
        _taps.isNotEmpty && now.difference(_taps.last) < _minGap;
    _taps.add(now);
    _taps.removeWhere((DateTime t) => now.difference(t) > _hurryWindow);

    final bool fast = _taps.length >= _hurryTaps || tooSoon;
    if (fast) {
      _hurryStart ??= now;
      if (!state.hurried && now.difference(_hurryStart!) >= _hurryFor) {
        HapticFeedback.lightImpact();
        state = state.copyWith(hurried: true);
      }
      _calm?.cancel();
      _calm = Timer(const Duration(seconds: 6), () {
        _hurryStart = null;
        state = state.copyWith(hurried: false);
      });
    } else if (_taps.length <= 1) {
      // A pause ends the streak; the three seconds start over.
      _hurryStart = null;
    }
    // While the veil is up the counter waits with you; taps resume counting
    // once it has faded.
    return !state.hurried;
  }

  void increment() {
    if (!_pace()) return;
    if (state.isSunnah) {
      _countSunnah();
      return;
    }

    final int next = state.count + 1;
    final bool justCompleted = next == state.target;

    if (justCompleted) {
      HapticFeedback.heavyImpact();
    } else {
      // Not selectionClick. That maps to iOS's UISelectionFeedbackGenerator,
      // the faintest tap the Taptic Engine makes — through a case it is easy
      // to miss entirely, which made the counter feel dead. A bead should
      // click back.
      HapticFeedback.mediumImpact();
    }

    state = state.copyWith(
      count: next,
      setsCompleted: justCompleted
          ? state.setsCompleted + 1
          : state.setsCompleted,
    );
    _prefs.setTasbihCount(next);

    if (justCompleted) _recordSet(state.dhikr.name, state.target);
  }

  /// One count in the after-prayer sequence, moving itself along at 33, 66 and
  /// 100 so the thumb never has to leave the button.
  void _countSunnah() {
    final int next = state.count + 1;
    if (next < state.target) {
      HapticFeedback.mediumImpact();
      state = state.copyWith(count: next);
      _prefs.setTasbihCount(next);
      return;
    }

    // A stage has just closed. Heavier than a count, so the hand knows the
    // dhikr changed underneath it without looking.
    HapticFeedback.heavyImpact();
    final SunnahRoutine routine = state.routine;
    final bool lastStage = state.stage == routine.stages.length - 1;

    if (!lastStage) {
      final int stage = state.stage + 1;
      final Dhikr dhikr = routine.stages[stage];
      state = state.copyWith(
        count: 0,
        stage: stage,
        dhikr: dhikr,
        target: dhikr.defaultTarget,
      );
      _prefs
        ..setTasbihCount(0)
        ..setTasbihStage(stage);
      return;
    }

    // The routine is done. Back to its first dhikr, ready to go again.
    final Dhikr first = routine.stages.first;
    state = state.copyWith(
      count: 0,
      stage: 0,
      dhikr: first,
      target: first.defaultTarget,
      setsCompleted: state.setsCompleted + 1,
      roundsCompleted: state.roundsCompleted + 1,
    );
    _prefs
      ..setTasbihCount(0)
      ..setTasbihStage(0);
    _recordSet(routine.name, routine.total);
  }

  /// Picking a different sunnah always starts it from its own first dhikr.
  void setRoutine(SunnahRoutine routine) {
    HapticFeedback.mediumImpact();
    final Dhikr first = routine.stages.first;
    state = state.copyWith(
      mode: TasbihMode.sunnah,
      routine: routine,
      stage: 0,
      count: 0,
      dhikr: first,
      target: first.defaultTarget,
    );
    _prefs
      ..setTasbihMode(TasbihMode.sunnah.name)
      ..setTasbihRoutine(routine.id)
      ..setTasbihStage(0)
      ..setTasbihCount(0);
  }

  /// Switching modes always starts clean — resuming a half-finished manual
  /// count as though it were the first stage of the Sunnah would misreport
  /// what was actually said.
  void setMode(TasbihMode mode) {
    if (mode == state.mode) return;
    HapticFeedback.mediumImpact();

    if (mode == TasbihMode.sunnah) {
      final Dhikr first = state.routine.stages.first;
      state = state.copyWith(
        mode: mode,
        stage: 0,
        count: 0,
        dhikr: first,
        target: first.defaultTarget,
      );
      _prefs
        ..setTasbihMode(mode.name)
        ..setTasbihStage(0)
        ..setTasbihCount(0);
      return;
    }

    state = state.copyWith(mode: mode, count: 0);
    _prefs
      ..setTasbihMode(mode.name)
      ..setTasbihCount(0);
  }

  void reset() {
    HapticFeedback.mediumImpact();
    if (state.isSunnah) {
      // Zeroing the count alone would leave someone parked on Allahu Akbar
      // with nothing said, which is not the start of the sequence.
      final Dhikr first = state.routine.stages.first;
      state = state.copyWith(
        count: 0,
        stage: 0,
        dhikr: first,
        target: first.defaultTarget,
      );
      _prefs
        ..setTasbihCount(0)
        ..setTasbihStage(0);
      return;
    }
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
    state = state.copyWith(dhikr: dhikr, target: dhikr.defaultTarget, count: 0);
    _prefs
      ..setTasbihDhikr(dhikr.name)
      ..setTasbihTarget(dhikr.defaultTarget)
      ..setTasbihCount(0);
  }

  /// A completed set is written to `users/{uid}/tasbih_sessions` for history.
  /// Failure here is silent by design — losing a log entry must never
  /// interrupt someone's dhikr.
  Future<void> _recordSet(String dhikr, int total) async {
    try {
      // Inside the try, not before it. Reaching for the auth repository can
      // itself throw when Firebase is not up, and this is called without an
      // await — so an escape here surfaces as an unhandled async error rather
      // than the silent no-op the caller is promised.
      final AuthRepository auth = ref.read(authRepositoryProvider);
      final String? uid = auth.uid;
      if (uid == null) return;
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('tasbih_sessions')
          .add(<String, Object?>{
            'dhikr': dhikr,
            'target': total,
            'count': total,
            'completedAt': FieldValue.serverTimestamp(),
          });
    } on Object catch (error) {
      debugPrint('Layla Pro: tasbih set not saved ($error)');
    }
  }
}
